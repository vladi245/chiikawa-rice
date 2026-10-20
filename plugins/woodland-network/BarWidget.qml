import QtQuick
import qs.Services.Networking
import "../../woodland"

BarGlyph {
  id: root

  readonly property var current: Object.values(NetworkService.networks).find(n => n.connected) ?? null
  readonly property bool wired: NetworkService.ethernetConnected
  readonly property bool online: wired || NetworkService.wifiConnected
  readonly property bool searching: NetworkService.connecting || NetworkService.scanningActive

  glyphScale: 1.06
  icon: {
    if (wired)
      return "ethernet";
    if (!NetworkService.wifiEnabled)
      return "wifi-off";
    if (NetworkService.wifiConnected)
      return NetworkService.getSignalInfo(current?.signal ?? 100, true).icon;
    return "wifi-0";
  }
  lit: online
  dim: !online && !searching
  label: wired ? "wired" : (current?.ssid ?? "")
  tooltip: {
    const lines = [];
    const wl = NetworkService.activeWifiDetails || {};
    const eth = NetworkService.activeEthernetDetails || {};
    if (NetworkService.airplaneModeEnabled)
      lines.push("Airplane mode");
    if (wired)
      lines.push(["Wired", eth.connectionName, eth.speed].filter(s => s).join(" · "), eth.ipv4 || "");
    if (NetworkService.wifiConnected && current)
      lines.push(current.ssid + " · " + current.signal + "%", [wl.ipv4, wl.band ? wl.band.split(" / ")[0] : "", wl.rateShort].filter(s => s).join(" · "));
    if (NetworkService.connecting)
      lines.push("Connecting to " + NetworkService.connectingTo + "…");
    if (lines.length === 0)
      lines.push(NetworkService.wifiEnabled ? "Not connected" : "Wi-Fi off");
    if (online && NetworkService.networkConnectivity && NetworkService.networkConnectivity !== "full")
      lines.push(NetworkService.networkConnectivity === "portal" ? "Sign-in required" : "Limited internet");
    return lines.filter(s => s).join("
");
  }

  onClicked: togglePanel()

  SequentialAnimation {
    running: root.searching && Woodland.fx
    loops: Animation.Infinite
    onRunningChanged: if (!running)
                        root.glyph.opacity = 1
    NumberAnimation { target: root.glyph; property: "opacity"; to: 0.3; duration: 700; easing.type: Easing.InOutSine }
    NumberAnimation { target: root.glyph; property: "opacity"; to: 1; duration: 700; easing.type: Easing.InOutSine }
  }
}
