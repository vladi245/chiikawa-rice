import QtQuick
import Quickshell

Column {
  id: details

  property var pairs: []
  property real keyWidth: Woodland.size(64)

  width: parent ? parent.width : 0
  spacing: Woodland.size(3)

  Repeater {
    model: details.pairs.filter(p => p[1] !== undefined && p[1] !== null && String(p[1]) !== "")
    delegate: Item {
      id: line
      required property var modelData
      property bool copied: false
      width: details.width
      height: value.implicitHeight

      Text {
        id: key
        width: details.keyWidth
        text: line.copied ? "copied!" : line.modelData[0]
        font.family: Woodland.font
        font.pointSize: 8
        font.weight: line.copied ? Font.Bold : Font.Normal
        color: line.copied ? Woodland.windowLight : Woodland.bark
      }
      Text {
        id: value
        anchors.left: key.right
        anchors.right: parent.right
        text: String(line.modelData[1])
        wrapMode: Text.WrapAnywhere
        font.family: Woodland.font
        font.pointSize: 8
        color: hover.hovered ? Woodland.windowLight : Woodland.mist
        HoverHandler {
          id: hover
          cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
          onTapped: {
            Quickshell.execDetached(["wl-copy", String(line.modelData[1])]);
            line.copied = true;
            copiedTimer.restart();
          }
        }
      }
      Timer {
        id: copiedTimer
        interval: 1200
        onTriggered: line.copied = false
      }
    }
  }
}
