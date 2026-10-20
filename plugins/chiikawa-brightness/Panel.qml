import QtQuick
import qs.Commons
import qs.Services.Compositor
import qs.Services.Hardware
import "../../chiikawa"

CPanel {
  id: root

  readonly property var displays: (BrightnessService.monitors || []).filter(m => m.brightnessControlAvailable)
  readonly property var night: Settings.data.nightLight
  readonly property bool nightOn: night.enabled
  readonly property real average: displays.length ? displays.reduce((sum, m) => sum + m.brightness, 0) / displays.length : 0

  contentPreferredWidth: Theme.size(380)
  contentPreferredHeight: Theme.size(220) + displays.length * Theme.size(78) + (displays.length > 1 ? Theme.size(44) : 0)
  scene.density: 14
  scene.clouds: false

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
    height: Theme.size(2)
  }

  CSlider {
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
      spacing: Theme.size(2)

      Text {
        width: parent.width
        text: modelData.modelData.name
        font.family: Theme.font
        font.pointSize: 9
        color: Theme.ink
      }
      Text {
        width: parent.width
        text: root.describe(modelData)
        elide: Text.ElideRight
        font.family: Theme.font
        font.pointSize: 7.5
        color: Theme.inkFaint
      }
      CSlider {
        icon: modelData.brightness > 0.5 ? "sun-high" : "sun-low"
        value: modelData.brightness
        step: Settings.data.brightness.brightnessStep / 100
        onMoved: v => modelData.setBrightness(Math.max(0.01, v))
      }
    }
  }

  CRow {
    icon: "moon-stars"
    title: "Night light"
    subtitle: {
      const when = root.night.autoSchedule ? "sunset to sunrise" : `${root.night.manualSunset} – ${root.night.manualSunrise}`;
      return `${root.night.nightTemp}K at night · ${when}`;
    }
    detail: root.nightOn ? "on" : "off"
    active: root.nightOn
    onClicked: toggleNight.toggled(!root.nightOn)

    CToggle {
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
