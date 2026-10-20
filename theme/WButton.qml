import QtQuick
import qs.Widgets

Item {
  id: button

  property string text: ""
  property string icon: ""
  property bool accent: false
  signal clicked

  readonly property bool hot: area.containsMouse && enabled

  implicitHeight: Woodland.size(26)
  implicitWidth: text !== "" ? row.implicitWidth + Woodland.size(22) : implicitHeight
  opacity: enabled ? 1 : 0.4
  scale: area.pressed ? 0.92 : (hot ? 1.05 : 1)
  Behavior on scale {
    SpringAnimation { spring: 6; damping: 0.3; epsilon: 0.005 }
  }

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: button.hot ? Woodland.blush : (button.accent ? Qt.alpha(Woodland.blush, 0.55) : Woodland.white)
    border.width: 1.5
    border.color: Woodland.line
    Behavior on color {
      ColorAnimation { duration: 160 }
    }
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Woodland.size(6)

    NIcon {
      visible: button.icon !== ""
      icon: button.icon || "point"
      pointSize: 10
      anchors.verticalCenter: parent.verticalCenter
      color: Woodland.line
    }
    Text {
      visible: button.text !== ""
      text: button.text
      anchors.verticalCenter: parent.verticalCenter
      font.family: Woodland.font
      font.pointSize: 8.5
      font.weight: Font.Bold
      color: Woodland.line
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
