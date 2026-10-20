import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Services.Networking
import qs.Widgets
import "../../woodland"

WPanel {
  id: root

  readonly property var adapter: BluetoothService.adapter
  readonly property var all: adapter && adapter.devices ? adapter.devices.values.filter(d => d && !d.blocked) : []
  readonly property var connected: BluetoothService.sortDevices(BluetoothService.dedupeDevices(all.filter(d => d.connected)))
  readonly property var paired: BluetoothService.sortDevices(BluetoothService.dedupeDevices(all.filter(d => !d.connected && (d.paired || d.trusted))))
  readonly property var nearby: BluetoothService.sortDevices(BluetoothService.dedupeDevices(all.filter(d => !d.paired && !d.trusted && (!Settings.data.network.bluetoothHideUnnamedDevices || named(d)))))
  property string openKey: ""        // device whose details are unfolded
  property int autoRevision: 0       // bumps after toggling auto-connect
  property bool startedScan: false
  property bool startedDiscoverable: false

  readonly property var rows: {
    const out = [];
    if (!BluetoothService.bluetoothAvailable)
      return [{ "k": "note", "t": "no bluetooth adapter found" }];
    if (BluetoothService.pinRequired)
      out.push({ "k": "pin" });
    if (BluetoothService.blocked)
      out.push({ "k": "note", "t": "blocked by rfkill or airplane mode" });
    if (!BluetoothService.enabled)
      return out.concat([{ "k": "note", "t": "the radio is quiet tonight" }]);
    const section = (title, list) => {
      if (list.length === 0)
        return;
      out.push({ "k": "caption", "t": title });
      for (const d of list)
        out.push({ "k": "device", "d": d });
    };
    section("connected", connected);
    section("paired", paired);
    if (BluetoothService.scanningActive) {
      out.push({ "k": "caption", "t": "nearby", "listening": true });
      for (const d of nearby)
        out.push({ "k": "device", "d": d });
    }
    if (connected.length + paired.length === 0 && !BluetoothService.scanningActive)
      out.push({ "k": "note", "t": "no devices yet" });
    return out;
  }

  contentPreferredWidth: Woodland.size(400)
  contentPreferredHeight: Woodland.size(540)
  scene.rainCount: 18

  function named(d) {
    const n = String(d.name || d.deviceName || "").trim();
    if (!n || ["unknown", "unnamed", "n/a", "na"].includes(n.toLowerCase()))
      return false;
    const addr = String(d.address || "").toLowerCase().replace(/[^0-9a-z]/g, "");
    return n.toLowerCase().replace(/[^0-9a-z]/g, "") !== addr;
  }

  function nameOf(d) {
    return d.name || d.deviceName || d.address || "device";
  }

  function statusOf(d) {
    const k = BluetoothService.getStatusKey(d);
    if (k)
      return k + "…";
    return d.connected ? "connected" : (d.paired || d.trusted ? "paired" : "available");
  }

  function activate(d) {
    if (BluetoothService.isDeviceBusy(d))
      return;
    if (BluetoothService.canDisconnect(d))
      BluetoothService.disconnectDevice(d);
    else if (BluetoothService.canConnect(d))
      BluetoothService.connectDeviceWithTrust(d);
    else if (BluetoothService.canPair(d))
      BluetoothService.pairDevice(d);
  }

  function ensureScan() {
    if (BluetoothService.enabled && !BluetoothService.scanningActive && !startedScan) {
      BluetoothService.setScanActive(true);
      startedScan = true;
    }
  }
  readonly property bool radioOn: BluetoothService.enabled
  onRadioOnChanged: ensureScan()
  Component.onCompleted: ensureScan()
  Component.onDestruction: {
    if (startedScan && BluetoothService.scanningActive)
      BluetoothService.setScanActive(false);
    if (startedDiscoverable && BluetoothService.discoverable)
      BluetoothService.setDiscoverable(false);
  }

  Header {
    icon: !BluetoothService.enabled ? "bluetooth-off" : (root.connected.length > 0 ? "bluetooth-connected" : "bluetooth")
    title: "Bluetooth"
    subtitle: {
      if (!BluetoothService.bluetoothAvailable)
        return "unavailable";
      if (!BluetoothService.enabled)
        return (root.adapter?.name ? root.adapter.name + " · " : "") + "off";
      const parts = [root.adapter?.name || ""];
      parts.push(root.connected.length > 0 ? root.connected.length + " connected" : "nothing connected");
      if (BluetoothService.discoverable)
        parts.push("visible");
      return parts.filter(s => s).join(" · ");
    }
    lit: root.connected.length > 0

    WButton {
      anchors.verticalCenter: parent.verticalCenter
      icon: "eye"
      accent: BluetoothService.discoverable
      enabled: BluetoothService.enabled && !Settings.data.network.disableDiscoverability
      onClicked: {
        const on = !BluetoothService.discoverable;
        BluetoothService.setDiscoverable(on);
        root.startedDiscoverable = on;
      }
    }
    WButton {
      anchors.verticalCenter: parent.verticalCenter
      icon: "refresh"
      accent: BluetoothService.scanningActive
      enabled: BluetoothService.enabled
      onClicked: {
        const on = !BluetoothService.scanningActive;
        BluetoothService.setScanActive(on);
        root.startedScan = on;
      }
    }
    WToggle {
      anchors.verticalCenter: parent.verticalCenter
      checked: BluetoothService.enabled
      enabled: BluetoothService.bluetoothAvailable && !BluetoothService.blocked
      onToggled: on => BluetoothService.setBluetoothEnabled(on)
    }
  }

  NListView {
    id: list
    width: parent.width
    height: Math.max(0, parent.height - y)
    model: root.rows
    spacing: Woodland.size(2)
    reserveScrollbarSpace: false
    horizontalPolicy: ScrollBar.AlwaysOff
    verticalPolicy: ScrollBar.AlwaysOff
    gradientColor: "transparent"
    wheelScrollMultiplier: 4.0

    delegate: Loader {
      required property var modelData
      readonly property var payload: modelData
      width: list.width
      sourceComponent: ({
                          "pin": pinRow,
                          "caption": captionRow,
                          "device": deviceRow,
                          "note": noteRow
                        })[modelData.k]
    }
  }

  Component {
    id: captionRow
    Item {
      readonly property var p: parent.payload
      width: list.width
      height: Woodland.size(26)

      Text {
        id: caption
        anchors.verticalCenter: parent.verticalCenter
        text: parent.p.t
        font.family: Woodland.font
        font.pointSize: 8
        color: Woodland.bark
      }

      Row {
        anchors.left: caption.right
        anchors.leftMargin: Woodland.size(10)
        anchors.verticalCenter: parent.verticalCenter
        visible: !!parent.p.listening

        Text {
          text: "listening"
          font.family: Woodland.font
          font.pointSize: 8
          font.italic: true
          color: Woodland.fog
        }
        Repeater {
          model: 3
          delegate: Text {
            id: dot
            required property int index
            text: "."
            font.family: Woodland.font
            font.pointSize: 8
            color: Woodland.windowLight
            opacity: 0.2
            SequentialAnimation on opacity {
              running: BluetoothService.scanningActive && Woodland.fx
              loops: Animation.Infinite
              PauseAnimation { duration: dot.index * 220 }
              NumberAnimation { to: 1; duration: 300 }
              NumberAnimation { to: 0.2; duration: 500 }
              PauseAnimation { duration: (2 - dot.index) * 220 }
            }
          }
        }
      }
    }
  }

  Component {
    id: deviceRow
    Column {
      id: entry
      readonly property var d: parent.payload.d
      readonly property string key: BluetoothService.deviceKey(d)
      readonly property bool open: root.openKey === key
      readonly property var battery: BluetoothService.getBatteryPercent(d)
      readonly property var signal: BluetoothService.getSignalPercent(d)
      readonly property bool known: d.paired || d.trusted
      width: list.width
      spacing: Woodland.size(6)

      WRow {
        id: row
        icon: BluetoothService.getDeviceIcon(entry.d)
        title: root.nameOf(entry.d)
        detail: entry.battery !== null ? entry.battery + "%" : ""
        subtitle: [root.statusOf(entry.d), entry.signal !== null ? entry.signal + "% signal" : ""].filter(s => s).join(" · ")
        active: entry.d.connected || entry.open
        busy: BluetoothService.isDeviceBusy(entry.d)
        onClicked: root.openKey = entry.open ? "" : entry.key

        WButton {
          visible: !row.busy
          text: entry.d.connected ? "disconnect" : (entry.known ? "connect" : "pair")
          accent: !entry.d.connected && row.hot
          onClicked: root.activate(entry.d)
        }
      }

      Column {
        visible: entry.open
        x: Woodland.size(46)
        width: parent.width - x - Woodland.size(8)
        spacing: Woodland.size(6)

        Details {
          width: parent.width
          pairs: [
            ["signal", entry.signal !== null ? BluetoothService.getSignalStrength(entry.d).replace(/^[^:]*:\s*/, "").toLowerCase() + " · " + entry.signal + "%" : "unknown"],
            ["battery", entry.battery !== null ? entry.battery + "%" : ""],
            ["paired", entry.d.paired ? "yes" : "no"],
            ["trusted", entry.d.trusted ? "yes" : "no"],
            ["address", entry.d.address]
          ]
        }

        Row {
          visible: entry.known
          spacing: Woodland.size(10)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Woodland.size(64)
            text: "auto-join"
            font.family: Woodland.font
            font.pointSize: 8
            color: Woodland.bark
          }
          WToggle {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.autoRevision >= 0 && BluetoothService.getDeviceAutoConnect(entry.d)
            onToggled: on => {
                         BluetoothService.setDeviceAutoConnect(entry.d, on);
                         root.autoRevision++;
                       }
          }
          Item {
            width: Woodland.size(12)
            height: 1
          }
          WButton {
            anchors.verticalCenter: parent.verticalCenter
            text: "unpair"
            onClicked: {
              root.openKey = "";
              BluetoothService.unpairDevice(entry.d);
            }
          }
        }

        Item {
          width: 1
          height: Woodland.size(4)
        }
      }
    }
  }

  Component {
    id: pinRow
    WRow {
      icon: "lock"
      title: "Pairing code required"
      subtitle: "enter the PIN shown on the device"
      active: true
      interactive: false
      implicitHeight: Woodland.size(84)

      Column {
        spacing: Woodland.size(6)
        Passphrase {
          id: pin
          width: Woodland.size(130)
          placeholder: "PIN"
          secret: false
          focusOnShow: true
          onAccepted: confirm.clicked()
          onCancelled: BluetoothService.cancelPairing()
        }
        Row {
          spacing: Woodland.size(6)
          WButton {
            text: "cancel"
            onClicked: BluetoothService.cancelPairing()
          }
          WButton {
            id: confirm
            text: "confirm"
            accent: pin.text.length > 0
            enabled: pin.text.length > 0
            onClicked: {
              BluetoothService.submitPin(pin.text);
              pin.text = "";
            }
          }
        }
      }
    }
  }

  Component {
    id: noteRow
    Text {
      width: list.width
      topPadding: Woodland.size(20)
      horizontalAlignment: Text.AlignHCenter
      text: parent.payload.t
      font.family: Woodland.font
      font.italic: true
      font.pointSize: 9
      color: Woodland.fog
    }
  }
}
