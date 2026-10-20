import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Compositor
import qs.Services.Hardware
import qs.Services.Location
import qs.Services.Media
import qs.Services.Networking
import qs.Services.Power
import qs.Services.System
import qs.Services.UI
import qs.Widgets
import "../../woodland"

WPanel {
  id: root

  contentPreferredWidth: Woodland.size(420)
  contentPreferredHeight: Woodland.size(hasMedia ? 650 : 574)
  spacing: Woodland.size(12)
  scene.rainCount: 30

  readonly property var now: Time.now
  readonly property string greeting: {
    const h = now.getHours();
    const part = h < 5 ? "night" : h < 12 ? "morning" : h < 18 ? "afternoon" : h < 22 ? "evening" : "night";
    return "good " + part + ", " + (HostService.displayName || Quickshell.env("USER") || "traveller").toLowerCase();
  }
  readonly property var monitor: BrightnessService.getMonitorForScreen(openScreen) || (BrightnessService.monitors.length > 0 ? BrightnessService.monitors[0] : null)
  readonly property string wifiName: {
    const nets = NetworkService.networks || {};
    for (const key in nets) {
      if (nets[key].connected)
        return nets[key].ssid;
    }
    return "";
  }
  readonly property string profileName: PowerProfileService.available ? PowerProfileService.getName() : "unavailable"
  readonly property bool weatherReady: Settings.data.location.weatherEnabled && LocationService.data.weather !== null && LocationService.data.weather !== undefined
  readonly property bool hasMedia: MediaService.currentPlayer !== null && MediaService.trackTitle !== ""
  readonly property string diskPath: Settings.data.controlCenter.diskPath || "/"
  property string uptime: "--"

  Component.onCompleted: SystemStatService.registerComponent("plugin:woodland-control")
  Component.onDestruction: SystemStatService.unregisterComponent("plugin:woodland-control")

  Process {
    id: uptimeReader
    command: ["cat", "/proc/uptime"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const s = parseFloat(text.trim().split(" ")[0]);
        if (!isNaN(s))
          root.uptime = Time.formatVagueHumanReadableDuration(s);
      }
    }
  }
  Timer {
    interval: 60000
    repeat: true
    running: true
    onTriggered: uptimeReader.running = true
  }

  function temperature(celsius) {
    const t = Settings.data.location.useFahrenheit ? LocationService.celsiusToFahrenheit(celsius) : celsius;
    return Math.round(t) + "°";
  }

  function closeThen(action) {
    const screen = openScreen;
    close();
    Qt.callLater(() => action(screen));
  }

  Item {
    width: parent.width
    height: hourColumn.implicitHeight

    Column {
      id: hourColumn
      spacing: Woodland.size(1)

      Text {
        text: root.greeting
        font.family: Woodland.font
        font.italic: true
        font.pointSize: 9
        color: Woodland.fog
      }
      Text {
        text: Qt.formatTime(root.now, "HH:mm")
        font.family: Woodland.font
        font.pointSize: 32
        font.weight: Font.Light
        color: Woodland.windowLight
        layer.enabled: Woodland.fx
        layer.effect: MultiEffect {
          shadowEnabled: true
          shadowColor: Woodland.windowLight
          shadowBlur: 0.8
          shadowOpacity: 0.35
          shadowHorizontalOffset: 0
          shadowVerticalOffset: 0
          blurMax: 24
        }
      }
      Text {
        text: Qt.formatDate(root.now, "dddd, d MMMM").toLowerCase()
        font.family: Woodland.font
        font.pointSize: 8.5
        color: Woodland.bark
      }
    }

    Column {
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.topMargin: Woodland.size(4)
      visible: root.weatherReady
      spacing: Woodland.size(3)

      Row {
        anchors.right: parent.right
        spacing: Woodland.size(6)
        NIcon {
          anchors.verticalCenter: parent.verticalCenter
          icon: root.weatherReady ? LocationService.weatherSymbolFromCode(LocationService.data.weather.current_weather.weathercode) : "cloud"
          pointSize: 16
          color: Woodland.mist
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.weatherReady ? root.temperature(LocationService.data.weather.current_weather.temperature) : ""
          font.family: Woodland.font
          font.pointSize: 16
          color: Woodland.mist
        }
      }
      Text {
        anchors.right: parent.right
        text: root.weatherReady ? (LocationService.weatherDescriptionFromCode(LocationService.data.weather.current_weather.weathercode) + " · " + Settings.data.location.name.split(",")[0]).toLowerCase() : ""
        font.family: Woodland.font
        font.pointSize: 7.5
        color: Woodland.fog
      }
      Row {
        anchors.right: parent.right
        spacing: Woodland.size(10)
        Repeater {
          model: root.weatherReady ? Math.min(3, LocationService.data.weather.daily.time.length - 1) : 0
          delegate: Column {
            required property int index
            readonly property int day: index + 1
            spacing: 0
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: Qt.formatDate(new Date(LocationService.data.weather.daily.time[parent.day].replace(/-/g, "/")), "ddd").toLowerCase()
              font.family: Woodland.font
              font.pointSize: 7
              color: Woodland.bark
            }
            NIcon {
              anchors.horizontalCenter: parent.horizontalCenter
              icon: LocationService.weatherSymbolFromCode(LocationService.data.weather.daily.weathercode[parent.day])
              pointSize: 9
              color: Woodland.fog
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.temperature(LocationService.data.weather.daily.temperature_2m_max[parent.day]).replace("°", "") + "/" + root.temperature(LocationService.data.weather.daily.temperature_2m_min[parent.day])
              font.family: Woodland.font
              font.pointSize: 7
              color: Woodland.fog
            }
          }
        }
      }
    }
  }

  Item {
    width: parent.width
    height: Woodland.size(30)

    Rectangle {
      id: avatarFrame
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Woodland.size(28)
      height: width
      radius: width / 2
      color: Qt.alpha(Woodland.moss, 0.6)
      border.width: 1
      border.color: Qt.alpha(Woodland.windowLight, 0.5)

      Image {
        id: avatar
        anchors.fill: parent
        anchors.margins: 1
        visible: false
        source: Settings.data.general.avatarImage ? "file://" + Settings.preprocessPath(Settings.data.general.avatarImage) : ""
        sourceSize: Qt.size(width * 2, height * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
      }
      Rectangle {
        id: avatarMask
        anchors.fill: avatar
        radius: width / 2
        visible: false
        layer.enabled: true
      }
      MultiEffect {
        anchors.fill: avatar
        source: avatar
        visible: avatar.status === Image.Ready
        maskEnabled: true
        maskSource: avatarMask
        saturation: -0.4
      }
      NIcon {
        anchors.centerIn: parent
        visible: avatar.status !== Image.Ready
        icon: "user"
        pointSize: 10
        color: Woodland.fog
      }
    }

    Column {
      anchors.left: avatarFrame.right
      anchors.leftMargin: Woodland.size(10)
      anchors.right: settingsButton.left
      anchors.rightMargin: Woodland.size(8)
      anchors.verticalCenter: parent.verticalCenter
      spacing: 0

      Text {
        width: parent.width
        elide: Text.ElideRight
        text: "up " + root.uptime
        font.family: Woodland.font
        font.pointSize: 8.5
        color: Woodland.fog
      }
      Text {
        width: parent.width
        elide: Text.ElideRight
        visible: BatteryService.batteryReady
        text: {
          const pct = Math.round(BatteryService.batteryPercentage) + "%";
          const state = BatteryService.batteryCharging ? "charging" : (BatteryService.batteryPluggedIn ? "plugged in" : "");
          const left = BatteryService.getTimeRemainingText(BatteryService.primaryDevice);
          return "battery " + pct + (state ? " · " + state : "") + (left && !BatteryService.batteryPluggedIn ? " · " + left.toLowerCase() : "");
        }
        font.family: Woodland.font
        font.pointSize: 7.5
        color: BatteryService.isCriticalBattery(BatteryService.primaryDevice) || BatteryService.isLowBattery(BatteryService.primaryDevice) ? Woodland.ember : Woodland.bark
      }
    }

    WButton {
      id: settingsButton
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      icon: "settings"
      onClicked: root.closeThen(screen => {
                                  const panel = PanelService.getPanel("settingsPanel", screen);
                                  if (panel)
                                    panel.open();
                                })
    }
  }

  component Tile: Item {
    id: tile
    property string icon: ""
    property string label: ""
    property string state: ""
    property bool on: false
    property bool available: true
    signal activated

    readonly property bool hot: tileArea.containsMouse && available
    property real light: on ? 1 : (hot ? 0.45 : 0)
    Behavior on light {
      NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }

    width: (grid.width - grid.columnSpacing * (grid.columns - 1)) / grid.columns
    height: Woodland.size(58)
    opacity: available ? 1 : 0.4

    Rectangle {
      anchors.fill: parent
      radius: Woodland.size(8)
      color: Qt.alpha(Woodland.moss, 0.28)
      border.width: 1
      border.color: Qt.alpha(Woodland.lit(Woodland.fog, tile.light), 0.18 + tile.light * 0.4)
    }

    Rectangle {
      anchors.fill: parent
      radius: Woodland.size(8)
      opacity: tile.light
      gradient: Gradient {
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 1.0; color: Qt.alpha(Woodland.windowLight, 0.2) }
      }
    }

    NIcon {
      anchors.left: parent.left
      anchors.leftMargin: Woodland.size(9)
      anchors.top: parent.top
      anchors.topMargin: Woodland.size(8)
      icon: tile.icon || "point"
      pointSize: 12
      color: Woodland.lit(Woodland.fog, tile.light)
      layer.enabled: Woodland.fx && tile.on
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Woodland.windowLight
        shadowBlur: 0.8
        shadowOpacity: 0.8
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
        blurMax: 14
      }
    }

    Column {
      anchors.left: parent.left
      anchors.leftMargin: Woodland.size(9)
      anchors.right: parent.right
      anchors.rightMargin: Woodland.size(6)
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Woodland.size(6)
      spacing: 0

      Text {
        width: parent.width
        text: tile.label
        elide: Text.ElideRight
        font.family: Woodland.font
        font.pointSize: 7.5
        color: Woodland.lit(Woodland.fog, tile.light)
      }
      Text {
        width: parent.width
        text: tile.state
        elide: Text.ElideRight
        font.family: Woodland.font
        font.pointSize: 6.5
        color: tile.on ? Woodland.mist : Woodland.bark
      }
    }

    MouseArea {
      id: tileArea
      anchors.fill: parent
      hoverEnabled: true
      enabled: tile.available
      cursorShape: Qt.PointingHandCursor
      onClicked: tile.activated()
    }
  }

  Grid {
    id: grid
    width: parent.width
    columns: 4
    columnSpacing: Woodland.size(6)
    rowSpacing: Woodland.size(6)

    Tile {
      icon: NetworkService.wifiEnabled ? "wifi" : "wifi-off"
      label: "Wi-Fi"
      on: NetworkService.wifiEnabled
      available: NetworkService.wifiAvailable
      state: !NetworkService.wifiEnabled ? "off" : (root.wifiName || (NetworkService.wifiConnected ? "connected" : (NetworkService.ethernetConnected ? "ethernet" : "not connected")))
      onActivated: NetworkService.setWifiEnabled(!NetworkService.wifiEnabled)
    }
    Tile {
      icon: BluetoothService.enabled ? "bluetooth" : "bluetooth-off"
      label: "Bluetooth"
      on: BluetoothService.enabled
      available: BluetoothService.bluetoothAvailable
      state: {
        if (!BluetoothService.enabled)
          return "off";
        const devices = BluetoothService.connectedDevices || [];
        return devices.length === 0 ? "on" : (devices.length === 1 ? (devices[0].name || "1 device") : devices.length + " devices");
      }
      onActivated: BluetoothService.setBluetoothEnabled(!BluetoothService.enabled)
    }
    Tile {
      icon: "photo"
      label: "Wallpaper"
      state: "choose"
      onActivated: root.closeThen(screen => PanelService.getPanel("wallpaperPanel", screen)?.toggle())
    }
    Tile {
      icon: PowerProfileService.noctaliaPerformanceMode ? "rocket" : "rocket-off"
      label: "Perf. mode"
      on: PowerProfileService.noctaliaPerformanceMode
      state: PowerProfileService.noctaliaPerformanceMode ? "no effects" : "off"
      onActivated: PowerProfileService.toggleNoctaliaPerformance()
    }
    Tile {
      icon: NotificationService.doNotDisturb ? "bell-off" : "bell"
      label: "Quiet"
      on: NotificationService.doNotDisturb
      state: NotificationService.doNotDisturb ? "do not disturb" : "off"
      onActivated: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
    }
    Tile {
      icon: root.profileName === "Performance" ? "gauge" : (root.profileName === "Power saver" ? "leaf" : "scale")
      label: "Power"
      on: root.profileName === "Performance" || root.profileName === "Power saver"
      available: PowerProfileService.available
      state: root.profileName.toLowerCase()
      onActivated: PowerProfileService.cycleProfile()
    }
    Tile {
      icon: IdleInhibitorService.isInhibited ? "coffee" : "coffee-off"
      label: "Keep awake"
      on: IdleInhibitorService.isInhibited
      state: !IdleInhibitorService.isInhibited ? "off" : (IdleInhibitorService.timeout !== null ? Time.formatVagueHumanReadableDuration(IdleInhibitorService.timeout) : "on")
      onActivated: IdleInhibitorService.manualToggle()
    }
    Tile {
      icon: "moon-stars"
      label: "Night light"
      on: Settings.data.nightLight.enabled
      state: Settings.data.nightLight.enabled ? (Settings.data.nightLight.forced ? "forced" : "scheduled") : "off"
      onActivated: {
        Settings.data.nightLight.forced = false;
        Settings.data.nightLight.enabled = !Settings.data.nightLight.enabled;
      }
    }
  }

  Column {
    width: parent.width
    spacing: 0

    WSlider {
      icon: AudioService.muted ? "volume-off" : "volume"
      value: AudioService.volume
      maximum: AudioService.maxVolume
      step: AudioService.stepVolume
      muted: AudioService.muted
      onMoved: v => AudioService.setVolume(v)
      onIconClicked: AudioService.setOutputMuted(!AudioService.muted)
    }
    WSlider {
      visible: AudioService.hasInput
      icon: AudioService.inputMuted ? "microphone-off" : "microphone"
      value: AudioService.inputVolume
      maximum: AudioService.maxVolume
      step: AudioService.stepVolume
      muted: AudioService.inputMuted
      onMoved: v => AudioService.setInputVolume(v)
      onIconClicked: AudioService.setInputMuted(!AudioService.inputMuted)
    }
    WSlider {
      visible: root.monitor !== null && (root.monitor.brightnessControlAvailable ?? true)
      icon: "sun"
      value: root.monitor ? root.monitor.brightness : 0
      onMoved: v => root.monitor?.setBrightness(v)
    }
  }

  Item {
    visible: root.hasMedia
    width: parent.width
    height: visible ? Woodland.size(64) : 0

    Rectangle {
      anchors.fill: parent
      radius: Woodland.size(8)
      color: Qt.alpha(Woodland.moss, 0.25)
      border.width: 1
      border.color: Qt.alpha(Woodland.fog, 0.18)
    }

    Item {
      id: artBox
      anchors.left: parent.left
      anchors.leftMargin: Woodland.size(8)
      anchors.verticalCenter: parent.verticalCenter
      width: Woodland.size(48)
      height: width

      Image {
        id: art
        anchors.fill: parent
        visible: false
        source: MediaService.trackArtUrl
        sourceSize: Qt.size(width * 2, height * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
      }
      Rectangle {
        id: artMask
        anchors.fill: parent
        radius: Woodland.size(6)
        visible: false
        layer.enabled: true
      }
      MultiEffect {
        anchors.fill: parent
        source: art
        visible: art.status === Image.Ready
        maskEnabled: true
        maskSource: artMask
        saturation: MediaService.isPlaying ? -0.15 : -0.7
        brightness: MediaService.isPlaying ? 0 : -0.15
        Behavior on saturation {
          NumberAnimation { duration: 400 }
        }
      }
      Rectangle {
        anchors.fill: parent
        visible: art.status !== Image.Ready
        radius: Woodland.size(6)
        color: Qt.alpha(Woodland.moss, 0.6)
        NIcon {
          anchors.centerIn: parent
          icon: "disc"
          pointSize: 14
          color: Woodland.fog
        }
      }
    }

    Column {
      anchors.left: artBox.right
      anchors.leftMargin: Woodland.size(10)
      anchors.right: controls.left
      anchors.rightMargin: Woodland.size(8)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Woodland.size(1)

      Text {
        width: parent.width
        elide: Text.ElideRight
        text: MediaService.trackTitle
        font.family: Woodland.font
        font.pointSize: 9
        color: Woodland.mist
      }
      Text {
        width: parent.width
        elide: Text.ElideRight
        text: [MediaService.trackArtist, MediaService.trackAlbum].filter(s => s).join(" · ") || MediaService.playerIdentity
        font.family: Woodland.font
        font.pointSize: 7.5
        color: Woodland.fog
      }
      Row {
        visible: MediaService.trackLength > 0
        width: parent.width
        spacing: Woodland.size(6)
        Item {
          width: parent.width - timeText.implicitWidth - parent.spacing
          height: timeText.implicitHeight
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 2
            radius: 1
            color: Qt.alpha(Woodland.moss, 0.9)
          }
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * Math.max(0, Math.min(1, MediaService.currentPosition / Math.max(1, MediaService.trackLength)))
            height: 2
            radius: 1
            color: Woodland.windowLight
          }
          MouseArea {
            anchors.fill: parent
            anchors.topMargin: -4
            anchors.bottomMargin: -4
            enabled: MediaService.canSeek
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => MediaService.seekByRatio(mouse.x / width)
          }
        }
        Text {
          id: timeText
          text: MediaService.positionString + " / " + MediaService.lengthString
          font.family: Woodland.font
          font.pointSize: 6.5
          color: Woodland.bark
        }
      }
    }

    Row {
      id: controls
      anchors.right: parent.right
      anchors.rightMargin: Woodland.size(8)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Woodland.size(4)

      WButton {
        icon: "player-skip-back"
        enabled: MediaService.canGoPrevious
        onClicked: MediaService.previous()
      }
      WButton {
        icon: MediaService.isPlaying ? "player-pause" : "player-play"
        accent: MediaService.isPlaying
        onClicked: MediaService.playPause()
      }
      WButton {
        icon: "player-skip-forward"
        enabled: MediaService.canGoNext
        onClicked: MediaService.next()
      }
    }
  }

  component Meter: Item {
    id: meter
    property string icon: ""
    property string text: ""
    property real ratio: 0
    property bool warn: false
    width: (stats.width - stats.spacing * 3) / 4
    height: Woodland.size(30)

    Row {
      spacing: Woodland.size(5)
      NIcon {
        anchors.verticalCenter: parent.verticalCenter
        icon: meter.icon
        pointSize: 9
        color: meter.warn ? Woodland.ember : Woodland.fog
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: meter.text
        font.family: Woodland.font
        font.pointSize: 8
        color: meter.warn ? Woodland.ember : Woodland.mist
      }
    }
    Rectangle {
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Woodland.size(4)
      width: parent.width - Woodland.size(6)
      height: 2
      radius: 1
      color: Qt.alpha(Woodland.moss, 0.9)
      Rectangle {
        width: parent.width * Math.max(0, Math.min(1, meter.ratio))
        height: parent.height
        radius: 1
        color: meter.warn ? Woodland.ember : Woodland.fog
        Behavior on width {
          NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }
      }
    }
  }

  Row {
    id: stats
    width: parent.width
    spacing: Woodland.size(8)

    Meter {
      icon: "cpu"
      text: Math.round(SystemStatService.cpuUsage) + "%"
      ratio: SystemStatService.cpuUsage / 100
      warn: SystemStatService.cpuWarning
    }
    Meter {
      icon: "temperature"
      text: Math.round(SystemStatService.cpuTemp) + "°"
      ratio: SystemStatService.cpuTemp / 100
      warn: SystemStatService.tempWarning
    }
    Meter {
      icon: "database"
      text: Math.round(SystemStatService.memPercent) + "%"
      ratio: SystemStatService.memPercent / 100
      warn: SystemStatService.memWarning
    }
    Meter {
      icon: "device-desktop-analytics"
      text: Math.round(SystemStatService.diskPercents[root.diskPath] ?? 0) + "%"
      ratio: (SystemStatService.diskPercents[root.diskPath] ?? 0) / 100
      warn: (SystemStatService.diskPercents[root.diskPath] ?? 0) >= SystemStatService.diskWarningThreshold
    }
  }

  Item {
    width: parent.width
    height: Math.max(Woodland.size(30), parent.height - y)

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Woodland.size(2)
      spacing: Woodland.size(8)

      WButton {
        icon: "lock"
        text: "lock"
        onClicked: root.closeThen(() => CompositorService.lock())
      }
      WButton {
        icon: "moon"
        text: "sleep"
        onClicked: root.closeThen(() => CompositorService.suspend())
      }
      WButton {
        icon: "power"
        text: "leave"
        onClicked: root.closeThen(screen => PanelService.getPanel("sessionMenuPanel", screen)?.toggle())
      }
    }
  }
}
