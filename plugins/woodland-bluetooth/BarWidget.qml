import QtQuick
import qs.Services.Networking
import "../../woodland"

BarGlyph {
  id: root

  readonly property var connected: BluetoothService.connectedDevices || []
  readonly property string names: connected.map(d => d.name || d.deviceName || "device").join(", ")

  shown: BluetoothService.bluetoothAvailable
  glyphScale: 1.13
  icon: !BluetoothService.enabled ? "bluetooth-off" : (connected.length > 0 ? "bluetooth-connected" : "bluetooth")
  lit: connected.length > 0
  dim: !BluetoothService.enabled
  label: names
  tooltip: {
    if (!BluetoothService.enabled)
      return BluetoothService.blocked ? "Bluetooth blocked" : "Bluetooth off";
    if (connected.length === 0)
      return "Bluetooth on · nothing connected";
    return connected.map(d => {
                           const battery = BluetoothService.getBatteryPercent(d);
                           return (d.name || d.deviceName || "device") + (battery !== null ? " · " + battery + "%" : "");
                         }).join("
");
  }

  onClicked: togglePanel()

  Rectangle {
    id: halo
    anchors.centerIn: parent
    width: root.capsuleHeight * 0.78
    height: width
    radius: width / 2
    color: "transparent"
    border.width: 1
    border.color: Woodland.windowLight
    visible: root.lit && Woodland.fx
    opacity: 0

    SequentialAnimation on opacity {
      running: halo.visible
      loops: Animation.Infinite
      NumberAnimation { to: 0.45; duration: 1600; easing.type: Easing.InOutSine }
      NumberAnimation { to: 0.05; duration: 1600; easing.type: Easing.InOutSine }
    }
    SequentialAnimation on scale {
      running: halo.visible
      loops: Animation.Infinite
      NumberAnimation { to: 1.15; duration: 1600; easing.type: Easing.InOutSine }
      NumberAnimation { to: 0.9; duration: 1600; easing.type: Easing.InOutSine }
    }
  }
}
