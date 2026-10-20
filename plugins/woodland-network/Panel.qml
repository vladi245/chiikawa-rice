import QtQuick
import QtQuick.Controls
import qs.Modules.Panels.Settings
import qs.Services.Networking
import qs.Services.System
import qs.Services.UI
import qs.Widgets
import "../../woodland"

WPanel {
  id: root

  readonly property var current: Object.values(NetworkService.networks).find(n => n.connected) ?? null
  readonly property var others: Object.values(NetworkService.networks).filter(n => !n.connected).sort((a, b) => b.signal - a.signal)
  readonly property var wl: NetworkService.activeWifiDetails || ({})
  readonly property var eth: NetworkService.activeEthernetDetails || ({})
  property string expanded: ""        // ssid whose passphrase field is open
  property bool currentOpen: false    // connection details unfolded
  property string ethOpen: ""         // ifname whose details are unfolded
  property bool addingHidden: false

  readonly property var rows: {
    const out = [];
    if (NetworkService.airplaneModeEnabled)
      out.push({ "k": "airplane" });
    if (root.current)
      out.push({ "k": "current" });
    if (NetworkService.ethernetAvailable)
      for (const e of NetworkService.ethernetInterfaces)
        out.push({ "k": "eth", "e": e });
    if (NetworkService.wifiEnabled) {
      out.push({ "k": "caption" });
      if (root.addingHidden)
        out.push({ "k": "hidden" });
      for (const n of root.others)
        out.push({ "k": "net", "n": n });
      if (root.others.length === 0 && !NetworkService.scanningActive)
        out.push({ "k": "empty" });
    } else if (!NetworkService.airplaneModeEnabled) {
      out.push({ "k": "off" });
    }
    return out;
  }

  contentPreferredWidth: Woodland.size(400)
  contentPreferredHeight: Woodland.size(560)
  scene.rainCount: 18

  function signalIcon(net) {
    return NetworkService.getSignalInfo(net.signal, net.connected).icon;
  }

  function connectivityText() {
    switch (NetworkService.networkConnectivity) {
    case "full":
      return "online";
    case "limited":
    case "unknown":
      return "limited internet";
    case "portal":
      return "sign-in required";
    default:
      return NetworkService.networkConnectivity || "";
    }
  }

  function traffic() {
    return "↓ " + SystemStatService.formatSpeed(SystemStatService.rxSpeed) + "/s   ↑ " + SystemStatService.formatSpeed(SystemStatService.txSpeed) + "/s";
  }

  function list(v) {
    return Array.isArray(v) ? v.join(", ") : (v || "");
  }

  function choose(net) {
    if (NetworkService.connecting)
      return;
    if (NetworkService.isEnterprise(net.security) && !net.existing) {
      // Enterprise logins need more fields than fit here; hand off to Settings.
      SettingsPanelService.openToTab(SettingsPanel.Tab.Connections, 0, root.openScreen);
      root.close();
    } else if (net.existing || !NetworkService.isSecured(net.security)) {
      expanded = "";
      NetworkService.connect(net.ssid);
    } else {
      expanded = expanded === net.ssid ? "" : net.ssid;
    }
  }

  Component.onCompleted: {
    SystemStatService.registerComponent("plugin:woodland-network");
    if (NetworkService.wifiEnabled && !NetworkService.scanningActive) {
      NetworkService.scan();
      NetworkService.refreshActiveWifiDetails();
    }
    if (NetworkService.ethernetConnected)
      NetworkService.refreshActiveEthernetDetails();
  }
  Component.onDestruction: SystemStatService.unregisterComponent("plugin:woodland-network")

  Header {
    icon: NetworkService.airplaneModeEnabled ? "plane" : (NetworkService.wifiEnabled ? "wifi" : "wifi-off")
    title: "Wi-Fi"
    subtitle: {
      if (NetworkService.connecting)
        return "connecting to " + NetworkService.connectingTo + "…";
      if (NetworkService.airplaneModeEnabled)
        return "airplane mode";
      if (NetworkService.ethernetConnected && !NetworkService.wifiConnected)
        return "wired · " + root.connectivityText();
      if (!NetworkService.wifiEnabled)
        return "off";
      return root.current ? root.current.ssid + " · " + root.connectivityText() : "not connected";
    }
    lit: NetworkService.wifiConnected || NetworkService.ethernetConnected

    WButton {
      anchors.verticalCenter: parent.verticalCenter
      icon: "plane"
      accent: NetworkService.airplaneModeEnabled
      onClicked: NetworkService.setAirplaneMode(!NetworkService.airplaneModeEnabled)
    }
    WButton {
      anchors.verticalCenter: parent.verticalCenter
      icon: "refresh"
      enabled: NetworkService.wifiEnabled && !NetworkService.scanningActive
      onClicked: NetworkService.scan()
    }
    WToggle {
      anchors.verticalCenter: parent.verticalCenter
      checked: NetworkService.wifiEnabled
      enabled: !NetworkService.airplaneModeEnabled && NetworkService.wifiAvailable
      onToggled: on => NetworkService.setWifiEnabled(on)
    }
  }

  Text {
    width: parent.width
    visible: NetworkService.lastError !== ""
    text: NetworkService.lastError
    wrapMode: Text.WordWrap
    font.family: Woodland.font
    font.pointSize: 8
    color: Woodland.blood
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
                          "airplane": airplaneRow,
                          "current": currentRow,
                          "eth": ethRow,
                          "caption": captionRow,
                          "hidden": hiddenRow,
                          "net": netRow,
                          "empty": emptyRow,
                          "off": offRow
                        })[modelData.k]
    }
  }

  Component {
    id: airplaneRow
    WRow {
      icon: "plane"
      title: "Airplane mode"
      subtitle: "radios are off"
      active: true
      interactive: false
      WButton {
        text: "turn off"
        onClicked: NetworkService.setAirplaneMode(false)
      }
    }
  }

  Component {
    id: currentRow
    Column {
      width: list.width
      spacing: Woodland.size(6)

      WRow {
        icon: root.current ? root.signalIcon(root.current) : "wifi"
        title: root.current?.ssid ?? ""
        detail: root.current ? root.current.signal + "%" : ""
        subtitle: [root.connectivityText(), (root.wl.band || "").split(" / ")[0], root.wl.rateShort].filter(s => s).join(" · ")
        active: true
        busy: root.current !== null && NetworkService.disconnectingFrom === root.current.ssid
        onClicked: {
          root.currentOpen = !root.currentOpen;
          if (root.currentOpen)
            NetworkService.refreshActiveWifiDetails();
        }

        WButton {
          icon: root.currentOpen ? "chevron-up" : "chevron-down"
          onClicked: parent.parent.clicked()
        }
        WButton {
          text: "disconnect"
          onClicked: NetworkService.disconnect(root.current.ssid)
        }
      }

      Details {
        visible: root.currentOpen
        x: Woodland.size(46)
        width: parent.width - x - Woodland.size(8)
        pairs: [
          ["traffic", root.traffic()],
          ["ipv4", root.wl.ipv4],
          ["gateway", root.wl.gateway4],
          ["dns", root.list(root.wl.dns4)],
          ["ipv6", root.list(root.wl.ipv6)],
          ["gateway6", root.list(root.wl.gateway6)],
          ["dns6", root.list(root.wl.dns6)],
          ["band", root.wl.band],
          ["speed", root.wl.rate],
          ["security", root.current?.security],
          ["interface", root.wl.ifname || NetworkService.activeWifiIf],
          ["mac", root.wl.hwAddr]
        ]
      }

      Item {
        width: 1
        height: root.currentOpen ? Woodland.size(4) : 0
      }
    }
  }

  Component {
    id: ethRow
    Column {
      id: ethEntry
      readonly property var e: parent.payload.e
      readonly property bool open: root.ethOpen === e.ifname
      readonly property bool isActive: e.ifname === NetworkService.activeEthernetIf
      width: list.width
      spacing: Woodland.size(6)

      WRow {
        icon: ethEntry.e.connected ? "ethernet" : "ethernet-off"
        title: ethEntry.e.connectionName || ethEntry.e.ifname
        detail: ethEntry.e.connectionName ? ethEntry.e.ifname : ""
        subtitle: ethEntry.e.connected ? [root.connectivityText(), ethEntry.isActive ? root.eth.speed : ""].filter(s => s).join(" · ") : (ethEntry.e.state || "disconnected")
        active: ethEntry.e.connected
        onClicked: {
          root.ethOpen = ethEntry.open ? "" : ethEntry.e.ifname;
          if (root.ethOpen) {
            NetworkService.activeEthernetIf = ethEntry.e.ifname;
            NetworkService.refreshActiveEthernetDetails();
          }
        }
        WButton {
          icon: ethEntry.open ? "chevron-up" : "chevron-down"
          onClicked: parent.parent.clicked()
        }
      }

      Details {
        visible: ethEntry.open
        x: Woodland.size(46)
        width: parent.width - x - Woodland.size(8)
        pairs: [
          ["traffic", ethEntry.e.connected ? root.traffic() : ""],
          ["ipv4", root.eth.ipv4],
          ["gateway", root.eth.gateway4],
          ["dns", root.list(root.eth.dns4)],
          ["ipv6", root.list(root.eth.ipv6)],
          ["gateway6", root.list(root.eth.gateway6)],
          ["dns6", root.list(root.eth.dns6)],
          ["speed", root.eth.speed],
          ["interface", root.eth.ifname || ethEntry.e.ifname],
          ["mac", root.eth.hwAddr]
        ]
      }

      Item {
        width: 1
        height: ethEntry.open ? Woodland.size(4) : 0
      }
    }
  }

  Component {
    id: captionRow
    Item {
      width: list.width
      height: Woodland.size(28)

      Text {
        id: caption
        anchors.verticalCenter: parent.verticalCenter
        text: "nearby"
        font.family: Woodland.font
        font.pointSize: 8
        color: Woodland.bark
      }

      Row {
        anchors.left: caption.right
        anchors.leftMargin: Woodland.size(10)
        anchors.verticalCenter: parent.verticalCenter
        visible: NetworkService.scanningActive

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
              running: NetworkService.scanningActive && Woodland.fx
              loops: Animation.Infinite
              PauseAnimation { duration: dot.index * 220 }
              NumberAnimation { to: 1; duration: 300 }
              NumberAnimation { to: 0.2; duration: 500 }
              PauseAnimation { duration: (2 - dot.index) * 220 }
            }
          }
        }
      }

      WButton {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.addingHidden ? "cancel" : "hidden network"
        onClicked: root.addingHidden = !root.addingHidden
      }
    }
  }

  Component {
    id: hiddenRow
    Column {
      width: list.width
      spacing: Woodland.size(6)

      Passphrase {
        id: ssidField
        width: parent.width
        placeholder: "network name"
        secret: false
        focusOnShow: true
      }
      Row {
        width: parent.width
        spacing: Woodland.size(8)
        Passphrase {
          id: hiddenPass
          width: parent.width - joinHidden.width - parent.spacing
          placeholder: "passphrase (blank if open)"
          onAccepted: joinHidden.clicked()
        }
        WButton {
          id: joinHidden
          anchors.verticalCenter: parent.verticalCenter
          text: "join"
          accent: ssidField.text.length > 0
          enabled: ssidField.text.length > 0
          onClicked: {
            NetworkService.connect(ssidField.text, hiddenPass.text, true);
            root.addingHidden = false;
          }
        }
      }
      Item {
        width: 1
        height: Woodland.size(4)
      }
    }
  }

  Component {
    id: netRow
    Column {
      id: entry
      readonly property var net: parent.payload.n
      readonly property bool secured: NetworkService.isSecured(net.security)
      readonly property bool enterprise: NetworkService.isEnterprise(net.security)
      readonly property bool open: root.expanded === net.ssid
      width: list.width

      WRow {
        id: row
        icon: root.signalIcon(entry.net)
        title: entry.net.ssid
        detail: [entry.secured ? "" : "", entry.net.existing ? "saved" : ""].filter(s => s).join("  ")
        subtitle: entry.net.signal + "% · " + (entry.enterprise ? "enterprise · opens settings" : (entry.secured ? entry.net.security : "open"))
        busy: (NetworkService.connecting && NetworkService.connectingTo === entry.net.ssid) || NetworkService.forgettingNetwork === entry.net.ssid
        active: entry.open
        onClicked: root.choose(entry.net)

        WButton {
          visible: entry.net.existing && row.hot
          text: "forget"
          onClicked: NetworkService.forget(entry.net.ssid)
        }
      }

      Item {
        width: parent.width
        height: entry.open ? Woodland.size(40) : 0
        clip: true
        Behavior on height {
          NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        Passphrase {
          id: pass
          anchors.left: parent.left
          anchors.leftMargin: Woodland.size(46)
          anchors.right: join.left
          anchors.rightMargin: Woodland.size(8)
          anchors.verticalCenter: parent.verticalCenter
          active: entry.open
          focusOnShow: true
          onAccepted: join.clicked()
          onCancelled: root.expanded = ""
        }

        WButton {
          id: join
          anchors.right: parent.right
          anchors.rightMargin: Woodland.size(8)
          anchors.verticalCenter: parent.verticalCenter
          text: "join"
          accent: pass.text.length > 0
          enabled: pass.text.length > 0
          onClicked: {
            NetworkService.connect(entry.net.ssid, pass.text);
            root.expanded = "";
          }
        }
      }
    }
  }

  Component {
    id: emptyRow
    Text {
      width: list.width
      topPadding: Woodland.size(12)
      horizontalAlignment: Text.AlignHCenter
      text: "no networks in the valley"
      font.family: Woodland.font
      font.italic: true
      font.pointSize: 9
      color: Woodland.fog
    }
  }

  Component {
    id: offRow
    Text {
      width: list.width
      topPadding: Woodland.size(24)
      horizontalAlignment: Text.AlignHCenter
      text: "the radio is quiet tonight"
      font.family: Woodland.font
      font.italic: true
      font.pointSize: 9
      color: Woodland.fog
    }
  }
}
