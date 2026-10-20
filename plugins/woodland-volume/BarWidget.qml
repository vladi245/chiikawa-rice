import QtQuick
import qs.Services.Media
import "../../woodland"

BarGlyph {
  id: root

  readonly property real level: AudioService.volume
  readonly property bool muted: AudioService.muted

  icon: muted ? "volume-off" : (level < 0.34 ? "volume-3" : (level < 0.67 ? "volume-2" : "volume"))
  dim: muted
  label: muted ? "mute" : Math.round(level * 100) + "%"
  showLabel: flashLabel.running
  tooltip: `Volume ${label} · ${AudioService.sink?.description ?? "no output"}` + (AudioService.hasInput ? `\nMic ${AudioService.inputMuted ? "muted" : Math.round(AudioService.inputVolume * 100) + "%"}` : "")

  onClicked: togglePanel()
  onMiddleClicked: AudioService.setOutputMuted(!muted)
  onWheel: delta => delta > 0 ? AudioService.increaseVolume() : AudioService.decreaseVolume()

  property bool _ready: false
  Component.onCompleted: Qt.callLater(() => _ready = true)
  onLevelChanged: if (_ready) {
                    flashLabel.restart();
                    if (Woodland.fx)
                      ripple.restart();
                  }
  onMutedChanged: if (_ready)
                    flashLabel.restart()

  Timer {
    id: flashLabel
    interval: 1400
  }

  Rectangle {
    id: ring
    anchors.centerIn: parent
    width: root.capsuleHeight * 0.5
    height: width
    radius: width / 2
    color: "transparent"
    border.width: 1
    border.color: Woodland.windowLight
    opacity: 0
  }

  ParallelAnimation {
    id: ripple
    NumberAnimation { target: ring; property: "scale"; from: 0.6; to: 1.7; duration: 600; easing.type: Easing.OutCubic }
    NumberAnimation { target: ring; property: "opacity"; from: 0.7; to: 0; duration: 600; easing.type: Easing.OutQuad }
  }
}
