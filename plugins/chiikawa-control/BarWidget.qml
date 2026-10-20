import QtQuick
import QtQuick.Effects
import "../../chiikawa"

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
    color: Theme.pink
    opacity: (root.awake ? 0.95 : 0.35) * glow.level
    Behavior on opacity {
      NumberAnimation { duration: 250 }
    }
    layer.enabled: Theme.fx
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Theme.pink
      shadowBlur: 1
      shadowOpacity: root.awake ? 1 : 0.4
      shadowScale: 1.6
      shadowHorizontalOffset: 0
      shadowVerticalOffset: 0
      blurMax: 16
    }
  }

  QtObject {
    id: glow
    property real level: 1
  }
  Timer {
    running: Theme.fx && root.awake
    repeat: true
    interval: 140
    onTriggered: glow.level = 0.8 + Math.random() * 0.2
    onRunningChanged: if (!running)
                        glow.level = 1
  }
}
