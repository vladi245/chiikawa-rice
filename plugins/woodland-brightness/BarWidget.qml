import QtQuick
import qs.Commons
import qs.Services.Hardware
import "../../woodland"

BarGlyph {
  id: root

  readonly property var monitor: BrightnessService.getMonitorForScreen(screen) ?? null
  readonly property real level: monitor?.brightness ?? 0
  readonly property bool available: monitor?.brightnessControlAvailable ?? false

  shown: available

  glyphScale: 0.93
  icon: level < 0.4 ? "sun-low" : (level < 0.75 ? "sun" : "sun-high")
  lit: level > 0.66
  label: Math.round(level * 100) + "%"
  showLabel: flashLabel.running
  tooltip: `Brightness ${label} · ${screen?.name ?? ""}` + (Settings.data.nightLight.enabled ? " · night light on" : "")

  onClicked: togglePanel()
  onWheel: delta => delta > 0 ? monitor?.increaseBrightness() : monitor?.decreaseBrightness()

  property bool _ready: false
  Component.onCompleted: Qt.callLater(() => _ready = true)
  onLevelChanged: if (_ready) {
                    flashLabel.restart();
                    if (Woodland.fx)
                      turn.restart();
                  }

  Timer {
    id: flashLabel
    interval: 1400
  }

  NumberAnimation {
    id: turn
    target: root.glyph
    property: "rotation"
    from: 0
    to: 45
    duration: 500
    easing.type: Easing.OutCubic
  }
}
