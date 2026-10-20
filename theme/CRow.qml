import QtQuick
import QtQuick.Effects
import qs.Widgets

Item {
  id: row

  property string icon: ""
  property string iconSource: ""
  property string title: ""
  property string subtitle: ""
  property string detail: ""
  property bool active: false
  property bool busy: false
  property bool interactive: true
  default property alias trailing: trailingRow.data
  signal clicked

  readonly property bool hot: interactive && hover.hovered
  readonly property real glow: hot ? 1 : (active ? 0.6 : 0)

  width: parent ? parent.width : 0
  implicitHeight: Theme.size(46)
  height: implicitHeight

  property real _glow: glow
  Behavior on _glow {
    NumberAnimation { duration: 240; easing.type: Easing.OutBack }
  }

  Rectangle {
    id: pill
    anchors.fill: parent
    radius: Theme.size(14)
    color: Qt.alpha(Theme.blush, 0.18 + row._glow * 0.32)
    border.width: 1.5
    border.color: Qt.alpha(Theme.line, Math.min(1, row._glow))
    opacity: Math.min(1, row._glow * 1.6)
    scale: 0.96 + Math.min(1, row._glow) * 0.04
  }

  Text {
    id: heart
    anchors.left: parent.left
    anchors.leftMargin: -Theme.size(3)
    anchors.top: parent.top
    anchors.topMargin: -Theme.size(4)
    text: "♥"
    font.pixelSize: Theme.size(11)
    color: Theme.pink
    visible: row.active
    scale: row.hot ? 1.25 : 1
    Behavior on scale {
      SpringAnimation { spring: 6; damping: 0.25; epsilon: 0.01 }
    }
  }

  Row {
    anchors.right: trailingRow.left
    anchors.rightMargin: Theme.size(6)
    anchors.verticalCenter: parent.verticalCenter
    visible: row.busy
    spacing: Theme.size(3)
    Repeater {
      model: 3
      delegate: Rectangle {
        id: dot
        required property int index
        width: Theme.size(5)
        height: width
        radius: width / 2
        color: Theme.pink
        SequentialAnimation on y {
          running: row.busy && Theme.fx
          loops: Animation.Infinite
          PauseAnimation { duration: dot.index * 120 }
          NumberAnimation { from: 0; to: -Theme.size(4); duration: 180; easing.type: Easing.OutQuad }
          NumberAnimation { to: 0; duration: 180; easing.type: Easing.InQuad }
          PauseAnimation { duration: (2 - dot.index) * 120 + 200 }
        }
      }
    }
  }

  Item {
    id: iconBox
    anchors.left: parent.left
    anchors.leftMargin: Theme.size(12)
    anchors.verticalCenter: parent.verticalCenter
    width: row.icon !== "" || row.iconSource !== "" ? Theme.size(22) : 0
    height: width
    scale: 1 + row._glow * 0.08

    NIcon {
      anchors.centerIn: parent
      visible: row.icon !== "" && row.iconSource === ""
      icon: row.icon || "point"
      pointSize: 13
      color: Theme.lit(Theme.inkSoft, row._glow)
    }

    Image {
      id: picture
      anchors.fill: parent
      visible: false
      source: row.iconSource
      sourceSize: Qt.size(width * 2, height * 2)
      asynchronous: true
    }
    MultiEffect {
      anchors.fill: parent
      source: picture
      visible: row.iconSource !== "" && picture.status === Image.Ready
      saturation: -0.3 + row._glow * 0.3
    }
  }

  Column {
    anchors.left: iconBox.right
    anchors.leftMargin: Theme.size(12)
    anchors.right: trailingRow.left
    anchors.rightMargin: Theme.size(8)
    anchors.verticalCenter: parent.verticalCenter
    spacing: 1

    Row {
      width: parent.width
      spacing: Theme.size(6)
      Text {
        width: Math.min(implicitWidth, parent.width - (detailText.visible ? detailText.implicitWidth + parent.spacing : 0))
        text: row.title
        elide: Text.ElideRight
        font.family: Theme.font
        font.pointSize: 10
        font.weight: row.active ? Font.Bold : Font.Normal
        color: row.active || row.hot ? Theme.ink : Theme.inkSoft
      }
      Text {
        id: detailText
        visible: text !== ""
        text: row.detail
        anchors.baseline: parent.children[0].baseline
        font.family: Theme.font
        font.pointSize: 8
        color: Theme.inkFaint
      }
    }
    Text {
      width: parent.width
      visible: text !== ""
      text: row.subtitle
      elide: Text.ElideRight
      font.family: Theme.font
      font.pointSize: 8
      color: Theme.lit(Theme.inkFaint, row._glow * 0.4)
    }
  }

  Row {
    id: trailingRow
    anchors.right: parent.right
    anchors.rightMargin: Theme.size(8)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Theme.size(6)
  }

  HoverHandler {
    id: hover
    enabled: row.interactive
    cursorShape: Qt.PointingHandCursor
  }
  TapHandler {
    enabled: row.interactive
    onTapped: row.clicked()
  }
}
