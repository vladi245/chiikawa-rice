import QtQuick
import qs.Commons
import qs.Services.Compositor
import qs.Services.Hardware
import "../../woodland"

WPanel {
  id: root

  readonly property var displays: (BrightnessService.monitors || []).filter(m => m.brightnessControlAvailable)
  readonly property var night: Settings.data.nightLight
  readonly property bool nightOn: night.enabled
  readonly property real average: displays.length ? displays.reduce((sum, m) => sum + m.brightness, 0) / displays.length : 0

  contentPreferredWidth: Woodland.size(380)
  contentPreferredHeight: Woodland.size(220) + displays.length * Woodland.size(78) + (displays.length > 1 ? Woodland.size(44) : 0)
  scene.rainCount: 14
  scene.birds: false

  function scaleOf(screen) {
    return CompositorService.displayScales[screen.name]?.scale ?? 1.0;
  }
  function describe(monitor) {
    const s = monitor.modelData, scale = scaleOf(s);
    const how = monitor.method === "ddcutil" ? "ddc/ci" : (monitor.method === "apple" ? "apple" : "backlight");
    return `${s.model || "display"} · ${Math.round(s.width * scale)}×${Math.round(s.height * scale)} @ ${scale}x · ${how}`;
  }

  Header {
    icon: root.nightOn ? "moon-stars" : "sun"
    title: "Light"
    subtitle: `${Math.round(root.average * 100)}%` + (root.displays.length > 1 ? ` across ${root.displays.length} displays` : "") + (root.nightOn ? ` · night light ${root.night.nightTemp}K` : "")
    lit: true
  }

  Item {
    width: parent.width
    height: Woodland.size(2)
  }

  WSlider {
    visible: root.displays.length > 1
    icon: "brightness-half"
    value: root.average
    onMoved: v => root.displays.forEach(m => m.setBrightness(Math.max(0.01, v)))
  }

  Repeater {
    model: root.displays
    delegate: Column {
      required property var modelData
      width: parent.width
      spacing: Woodland.size(2)

      Text {
        width: parent.width
        text: modelData.modelData.name
        font.family: Woodland.font
        font.pointSize: 9
        color: Woodland.mist
      }
      Text {
        width: parent.width
        text: root.describe(modelData)
        elide: Text.ElideRight
        font.family: Woodland.font
        font.pointSize: 7.5
        color: Woodland.bark
      }
      WSlider {
        icon: modelData.brightness > 0.5 ? "sun-high" : "sun-low"
        value: modelData.brightness
        step: Settings.data.brightness.brightnessStep / 100
        onMoved: v => modelData.setBrightness(Math.max(0.01, v))
      }
    }
  }

  WRow {
    icon: "moon-stars"
    title: "Night light"
    subtitle: {
      const when = root.night.autoSchedule ? "sunset to sunrise" : `${root.night.manualSunset} – ${root.night.manualSunrise}`;
      return `${root.night.nightTemp}K at night · ${when}`;
    }
    detail: root.nightOn ? "on" : "off"
    active: root.nightOn
    onClicked: toggleNight.toggled(!root.nightOn)

    WToggle {
      id: toggleNight
      anchors.verticalCenter: parent.verticalCenter
      checked: root.nightOn
      onToggled: on => {
                   Settings.data.nightLight.enabled = on;
                   Settings.data.nightLight.forced = false;
                 }
    }
  }
}
