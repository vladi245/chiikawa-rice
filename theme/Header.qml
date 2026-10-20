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
  height: Woodland.size(40)

  Rectangle {
    id: sticker
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    visible: header.icon !== ""
    width: visible ? Woodland.size(32) : 0
    height: width
    radius: width / 2
    color: header.lit ? Woodland.blush : Woodland.white
    border.width: 1.5
    border.color: Woodland.line
    Behavior on color {
      ColorAnimation { duration: 300 }
    }

    NIcon {
      anchors.centerIn: parent
      icon: header.icon || "point"
      pointSize: 12
      color: Woodland.line
    }
  }

  Column {
    anchors.left: sticker.visible ? sticker.right : parent.left
    anchors.leftMargin: sticker.visible ? Woodland.size(10) : 0
    anchors.right: trailingRow.left
    anchors.rightMargin: Woodland.size(8)
    anchors.verticalCenter: parent.verticalCenter
    spacing: 0

    Text {
      width: parent.width
      text: header.title
      elide: Text.ElideRight
      font.family: Woodland.display
      font.pointSize: 13.5
      font.weight: Font.ExtraBold
      color: Woodland.mist
    }
    Text {
      width: parent.width
      visible: text !== ""
      text: header.subtitle
      elide: Text.ElideRight
      font.family: Woodland.font
      font.pointSize: 8
      color: Woodland.bark
    }
  }

  Row {
    id: trailingRow
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Woodland.size(8)
  }

  Row {
    anchors.bottom: parent.bottom
    anchors.bottomMargin: -Woodland.size(5)
    spacing: Woodland.size(5)
    Repeater {
      model: Math.max(0, Math.floor(header.width / Woodland.size(10)))
      delegate: Rectangle {
        required property int index
        width: Woodland.size(4)
        height: width
        radius: width / 2
        color: index % 6 === 0 ? Woodland.blush : Qt.alpha(Woodland.bark, 0.35)
      }
    }
  }
}
