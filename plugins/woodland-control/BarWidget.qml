import QtQuick
import QtQuick.Effects
import "../../woodland"

BarGlyph {
  id: root

  icon: "building-cottage"
  tooltip: "Control center"
  onClicked: togglePanel()

  readonly property bool awake: hot || panelOpen

  Rectangle {
    id: windowLight
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: -root.capsuleHeight * 0.072
    width: Math.max(2, root.capsuleHeight * 0.1)
    height: width
    radius: width / 2
    color: Woodland.windowLight
    opacity: (root.awake ? 0.95 : 0.35) * lamp.level
    Behavior on opacity {
      NumberAnimation { duration: 250 }
    }
    layer.enabled: Woodland.fx
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Woodland.windowLight
      shadowBlur: 1
      shadowOpacity: root.awake ? 1 : 0.4
      shadowScale: 1.6
      shadowHorizontalOffset: 0
      shadowVerticalOffset: 0
      blurMax: 16
    }
  }

  QtObject {
    id: lamp
    property real level: 1
  }
  Timer {
    running: Woodland.fx && root.awake
    repeat: true
    interval: 140
    onTriggered: lamp.level = 0.8 + Math.random() * 0.2
    onRunningChanged: if (!running)
                        lamp.level = 1
  }
}
