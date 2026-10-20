import QtQuick
import qs.Widgets

Item {
  id: header

  property string icon: ""
  property string title: ""
  property string subtitle: ""
  property bool lit: false
  default property alias trailing: trailingRow.data

  width: parent ? parent.width : 0
  height: Theme.size(40)

  Rectangle {
    id: sticker
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    visible: header.icon !== ""
    width: visible ? Theme.size(32) : 0
    height: width
    radius: width / 2
    color: header.lit ? Theme.blush : Theme.white
    border.width: 1.5
    border.color: Theme.line
    Behavior on color {
      ColorAnimation { duration: 300 }
    }

    NIcon {
      anchors.centerIn: parent
      icon: header.icon || "point"
      pointSize: 12
      color: Theme.line
    }
  }

  Column {
    anchors.left: sticker.visible ? sticker.right : parent.left
    anchors.leftMargin: sticker.visible ? Theme.size(10) : 0
    anchors.right: trailingRow.left
    anchors.rightMargin: Theme.size(8)
    anchors.verticalCenter: parent.verticalCenter
    spacing: 0

    Text {
      width: parent.width
      text: header.title
      elide: Text.ElideRight
      font.family: Theme.display
      font.pointSize: 13.5
      font.weight: Font.ExtraBold
      color: Theme.ink
    }
    Text {
      width: parent.width
      visible: text !== ""
      text: header.subtitle
      elide: Text.ElideRight
      font.family: Theme.font
      font.pointSize: 8
      color: Theme.inkFaint
    }
  }

  Row {
    id: trailingRow
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Theme.size(8)
  }

  Row {
    anchors.bottom: parent.bottom
    anchors.bottomMargin: -Theme.size(5)
    spacing: Theme.size(5)
    Repeater {
      model: Math.max(0, Math.floor(header.width / Theme.size(10)))
      delegate: Rectangle {
        required property int index
        width: Theme.size(4)
        height: width
        radius: width / 2
        color: index % 6 === 0 ? Theme.blush : Qt.alpha(Theme.inkFaint, 0.35)
      }
    }
  }
}
