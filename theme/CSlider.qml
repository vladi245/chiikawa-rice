import QtQuick
import qs.Widgets

Item {
  id: slider

  property real value: 0
  property real maximum: 1
  property real step: 0.05
  property string icon: ""
  property bool muted: false
  property bool showValue: true
  signal moved(real value)
  signal iconClicked

  readonly property bool held: area.pressed
  property real _dragValue: 0
  readonly property real shown: held ? _dragValue : value
  readonly property real ratio: Math.max(0, Math.min(1, shown / maximum))

  implicitHeight: Theme.size(30)
  width: parent ? parent.width : 200

  function setFromX(x) {
    const r = Math.max(0, Math.min(1, (x - track.x) / track.width));
    _dragValue = Math.round(r * maximum / step * 4) * step / 4;
    moved(_dragValue);
  }

  NIcon {
    id: glyph
    visible: slider.icon !== ""
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: visible ? Theme.size(20) : 0
    icon: slider.icon || "point"
    pointSize: 12
    color: slider.muted ? Theme.inkFaint : Theme.lit(Theme.inkSoft, slider.ratio * 0.8)
    MouseArea {
      anchors.fill: parent
      anchors.margins: -4
      cursorShape: Qt.PointingHandCursor
      onClicked: slider.iconClicked()
    }
  }

  Item {
    id: track
    anchors.left: glyph.right
    anchors.leftMargin: glyph.visible ? Theme.size(10) : 0
    anchors.right: label.left
    anchors.rightMargin: label.visible ? Theme.size(12) : Theme.size(6)
    anchors.verticalCenter: parent.verticalCenter
    height: Theme.size(10)

    Rectangle {
      anchors.fill: parent
      radius: height / 2
      color: Theme.tan
      border.width: 1.5
      border.color: Theme.line
    }

    Rectangle {
      id: fill
      x: 1.5
      y: 1.5
      height: parent.height - 3
      radius: height / 2
      width: Math.max(height, (parent.width - 3) * slider.ratio)
      opacity: slider.muted ? 0.35 : 1
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Theme.blush }
        GradientStop { position: 1.0; color: Theme.pink }
      }
      Behavior on width {
        enabled: Theme.fx && !slider.held
        NumberAnimation { duration: 200; easing.type: Easing.OutBack }
      }
    }

    Rectangle {
      id: handle
      readonly property real d: Theme.size(18)
      width: d * (slider.held ? 1.18 : 1)
      height: d * (slider.held ? 0.86 : 1)
      radius: height / 2
      anchors.verticalCenter: parent.verticalCenter
      x: fill.x + fill.width - width / 2
      color: slider.muted ? Theme.tan : Theme.white
      border.width: 1.5
      border.color: Theme.line
      Behavior on width {
        SpringAnimation { spring: 6; damping: 0.3; epsilon: 0.1 }
      }
      Behavior on height {
        SpringAnimation { spring: 6; damping: 0.3; epsilon: 0.1 }
      }

      Repeater {
        model: 2
        delegate: Rectangle {
          required property int index
          width: Math.max(2, handle.d * 0.12)
          height: slider.held ? 1.5 : width
          radius: width / 2
          color: Theme.line
          x: handle.width / 2 + (index === 0 ? -1 : 1) * handle.d * 0.18 - width / 2
          y: handle.height * 0.42 - height / 2
        }
      }
    }
  }

  Text {
    id: label
    visible: slider.showValue
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: Theme.size(38)
    horizontalAlignment: Text.AlignRight
    text: slider.muted ? "shh" : Math.round(slider.shown * 100) + "%"
    font.family: Theme.font
    font.pointSize: 8.5
    font.weight: Font.Bold
    color: slider.held ? Theme.pink : Theme.inkSoft
  }

  MouseArea {
    id: area
    anchors.fill: track
    anchors.topMargin: -Theme.size(10)
    anchors.bottomMargin: -Theme.size(10)
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onPressed: mouse => slider.setFromX(mouse.x + track.x)
    onPositionChanged: mouse => {
                         if (pressed)
                           slider.setFromX(mouse.x + track.x);
                       }
    onWheel: wheel => {
               const next = Math.max(0, Math.min(slider.maximum, slider.value + (wheel.angleDelta.y > 0 ? slider.step : -slider.step)));
               slider.moved(next);
             }
  }
}
