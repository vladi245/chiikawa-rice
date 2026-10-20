import QtQuick
import qs.Widgets

Item {
  id: button

  property string text: ""
  property string icon: ""
  property bool accent: false
  signal clicked

  readonly property bool hot: area.containsMouse && enabled

  implicitHeight: Theme.size(26)
  implicitWidth: text !== "" ? row.implicitWidth + Theme.size(22) : implicitHeight
  opacity: enabled ? 1 : 0.4
  scale: area.pressed ? 0.92 : (hot ? 1.05 : 1)
  Behavior on scale {
    SpringAnimation { spring: 6; damping: 0.3; epsilon: 0.005 }
  }

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: button.hot ? Theme.blush : (button.accent ? Qt.alpha(Theme.blush, 0.55) : Theme.white)
    border.width: 1.5
    border.color: Theme.line
    Behavior on color {
      ColorAnimation { duration: 160 }
    }
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Theme.size(6)

    NIcon {
      visible: button.icon !== ""
      icon: button.icon || "point"
      pointSize: 10
      anchors.verticalCenter: parent.verticalCenter
      color: Theme.line
    }
    Text {
      visible: button.text !== ""
      text: button.text
      anchors.verticalCenter: parent.verticalCenter
      font.family: Theme.font
      font.pointSize: 8.5
      font.weight: Font.Bold
      color: Theme.line
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    enabled: button.enabled
    cursorShape: Qt.PointingHandCursor
    onClicked: button.clicked()
  }
}
