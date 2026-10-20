import QtQuick
import QtQuick.Shapes

// Plain QtQuick only (no Noctalia imports), so the lock screen can use it.
Item {
  id: mochi

  property string kind: "chiikawa"
  property string mood: "idle"
  property bool animated: true
  property bool bobbing: false
  property bool feet: false
  property bool arms: false
  property bool walking: false
  property bool cheer: false
  property string headgear: "none"
  property color gearColor: "#f2a0b4"
  property color lineColor: "#3f2a26"

  readonly property var _specs: ({
                                   "hachiware": {
                                     "body": "#fbf9f7",
                                     "eyes": [[37.8, 39.1], [63.7, 39.6]],
                                     "eyeR": 5.3,
                                     "mouth": [50.5, 49.2],
                                     "head": { "cy": 42, "rx": 46, "ry": 28, "left": 6.8, "right": 93.4 }
                                   },
                                   "chiikawa": {
                                     "body": "#fafafa",
                                     "eyes": [[37.1, 37], [63.8, 37.5]],
                                     "eyeR": 5.4,
                                     "mouth": [50.4, 47.4],
                                     "head": { "cy": 40, "rx": 47, "ry": 27, "left": 5.5, "right": 94.3 }
                                   },
                                   "usagi": {
                                     "body": "#fff0cf",
                                     "eyes": [[40.1, 51.5], [60.3, 51.5]],
                                     "eyeR": 3.8,
                                     "mouth": [50.2, 60.3],
                                     "head": { "cy": 55, "rx": 39, "ry": 25, "left": 13.9, "right": 85.9 }
                                   },
                                   "momonga": {
                                     "body": "#f8f8f8",
                                     "eyes": [[30.65, 45.05], [57.15, 44.75]],
                                     "eyeR": 6.2,
                                     "mouth": [44.4, 53.3],
                                     "head": { "cx": 44, "cy": 47, "rx": 36, "ry": 27, "left": 9, "right": 79 }
                                   }
                                 })
  readonly property var _s: _specs[kind] || _specs.chiikawa
  property color bodyColor: _s.body

  function boing() {
    if (animated)
      squish.restart();
  }

  readonly property real _stroke: Math.max(1.8, 110 / Math.max(1, width))

  implicitWidth: 48
  implicitHeight: width

  onHeadgearChanged: if (animated && headgear !== "none")
                       gearDrop.restart()
  onCheerChanged: if (cheer && animated)
                    hop.restart()

  Item {
    id: body
    width: 100
    height: 100
    scale: mochi.width / 100
    transformOrigin: Item.TopLeft

    property real bob: 0
    property real sx: 1
    property real sy: 1
    property real tilt: 0
    property real breath: 0

    SequentialAnimation on breath {
      running: mochi.animated && mochi.visible && !mochi.walking && !mochi.bobbing
      loops: Animation.Infinite
      NumberAnimation { from: 0; to: 1; duration: 1600; easing.type: Easing.InOutSine }
      NumberAnimation { from: 1; to: 0; duration: 1600; easing.type: Easing.InOutSine }
    }
    SequentialAnimation on bob {
      running: mochi.animated && (mochi.bobbing || mochi.walking) && mochi.visible
      loops: Animation.Infinite
      NumberAnimation { from: 0; to: mochi.walking ? -2.5 : -6; duration: mochi.walking ? 170 : 260; easing.type: Easing.OutQuad }
      NumberAnimation { to: 0; duration: mochi.walking ? 170 : 260; easing.type: Easing.InQuad }
      onRunningChanged: if (!running)
                          body.bob = 0
    }
    SequentialAnimation on tilt {
      running: mochi.animated && mochi.walking && mochi.visible
      loops: Animation.Infinite
      NumberAnimation { from: -4; to: 4; duration: 340; easing.type: Easing.InOutSine }
      NumberAnimation { from: 4; to: -4; duration: 340; easing.type: Easing.InOutSine }
      onRunningChanged: if (!running)
                          body.tilt = 0
    }

    SequentialAnimation {
      id: squish
      ParallelAnimation {
        NumberAnimation { target: body; property: "sx"; to: 1.1; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: body; property: "sy"; to: 0.88; duration: 90; easing.type: Easing.OutQuad }
      }
      ParallelAnimation {
        SpringAnimation { target: body; property: "sx"; to: 1; spring: 7; damping: 0.22; epsilon: 0.005 }
        SpringAnimation { target: body; property: "sy"; to: 1; spring: 7; damping: 0.22; epsilon: 0.005 }
      }
    }
    SequentialAnimation {
      id: hop
      NumberAnimation { target: body; property: "bob"; to: -10; duration: 160; easing.type: Easing.OutQuad }
      NumberAnimation { target: body; property: "bob"; to: 0; duration: 220; easing.type: Easing.OutBounce }
      ScriptAction { script: mochi.boing() }
    }

    transform: [
      Scale {
        origin.x: 50
        origin.y: 100
        xScale: body.sx * (1 + body.breath * 0.012)
        yScale: body.sy * (1 - body.breath * 0.012)
      },
      Rotation { origin.x: 50; origin.y: 100; angle: body.tilt },
      Translate { y: body.bob }
    ]

    Image {
      anchors.fill: parent
      source: Qt.resolvedUrl("art/" + mochi.kind + ".png")
      sourceSize: Qt.size(Math.min(512, mochi.width * 2), Math.min(512, mochi.width * 2))
      fillMode: Image.PreserveAspectFit
      smooth: true
      mipmap: true
    }

    Item {
      id: gear
      width: 100
      height: 100
      visible: mochi.headgear !== "none"
      property real drop: 0
      transform: Translate { y: gear.drop }

      readonly property var h: mochi._s.head
      readonly property bool overEar: mochi.headgear === "headphones" || mochi.headgear === "wireless" || mochi.headgear === "headset"

      SequentialAnimation {
        id: gearDrop
        PropertyAction { target: gear; property: "drop"; value: -46 }
        NumberAnimation { target: gear; property: "drop"; to: 0; duration: 520; easing.type: Easing.OutBounce }
        ScriptAction { script: mochi.boing() }
      }

      Shape {
        anchors.fill: parent
        visible: gear.overEar
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeColor: mochi.lineColor
          strokeWidth: 10
          capStyle: ShapePath.RoundCap
          fillColor: "transparent"
          PathAngleArc { centerX: gear.h.cx ?? 50; centerY: gear.h.cy; radiusX: gear.h.rx; radiusY: gear.h.ry; startAngle: 192; sweepAngle: 156 }
        }
        ShapePath {
          strokeColor: mochi.gearColor
          strokeWidth: 5
          capStyle: ShapePath.RoundCap
          fillColor: "transparent"
          PathAngleArc { centerX: gear.h.cx ?? 50; centerY: gear.h.cy; radiusX: gear.h.rx; radiusY: gear.h.ry; startAngle: 192; sweepAngle: 156 }
        }
        ShapePath {
          strokeColor: mochi.headgear === "headphones" ? mochi.lineColor : "transparent"
          strokeWidth: 2.5
          capStyle: ShapePath.RoundCap
          fillColor: "transparent"
          PathSvg {
            path: {
              const x = gear.h.right + 2, y = gear.h.cy + 14;
              return `M ${x} ${y} C ${x + 9} ${y + 6} ${x - 3} ${y + 14} ${x + 5} ${y + 20} C ${x + 10} ${y + 24} ${x + 3} ${y + 30} ${x + 8} ${y + 36}`;
            }
          }
        }
        ShapePath {
          strokeColor: mochi.headgear === "headset" ? mochi.lineColor : "transparent"
          strokeWidth: 3.5
          capStyle: ShapePath.RoundCap
          fillColor: "transparent"
          PathSvg {
            path: {
              const x = gear.h.left, y = gear.h.cy + 12, m = mochi._s.mouth;
              return `M ${x} ${y} Q ${x + 6} ${m[1] + 10} ${m[0] - 15} ${m[1] + 4}`;
            }
          }
        }
        ShapePath {
          strokeColor: mochi.headgear === "headset" ? mochi.lineColor : "transparent"
          strokeWidth: mochi._stroke * 0.8
          fillColor: mochi.headgear === "headset" ? mochi.gearColor : "transparent"
          PathAngleArc { centerX: mochi._s.mouth[0] - 12; centerY: mochi._s.mouth[1] + 3.5; radiusX: 4; radiusY: 4; startAngle: 0; sweepAngle: 360 }
        }
      }

      Repeater {
        model: gear.overEar ? 2 : 0
        delegate: Rectangle {
          required property int index
          x: index === 0 ? gear.h.left - 9 : gear.h.right - 7
          y: gear.h.cy - 12
          width: 16
          height: 26
          radius: 7
          color: mochi.gearColor
          border.width: mochi._stroke * 0.9
          border.color: mochi.lineColor

          Rectangle {
            visible: mochi.headgear === "wireless" && index === 1
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - 9
            width: 4
            height: 4
            radius: 2
            color: "#7fd18b"
            SequentialAnimation on opacity {
              running: mochi.animated && parent.visible
              loops: Animation.Infinite
              NumberAnimation { from: 1; to: 0.2; duration: 600 }
              NumberAnimation { from: 0.2; to: 1; duration: 600 }
            }
          }
        }
      }

      Repeater {
        model: mochi.headgear === "earbuds" ? 2 : 0
        delegate: Item {
          required property int index
          x: index === 0 ? gear.h.left - 5 : gear.h.right - 7
          y: gear.h.cy - 8
          width: 12
          height: 24
          Rectangle {
            x: (parent.width - 5) / 2
            y: 8
            width: 5
            height: 15
            radius: 2.5
            color: mochi.gearColor
            border.width: mochi._stroke * 0.6
            border.color: mochi.lineColor
          }
          Rectangle {
            width: 12
            height: 12
            radius: 6
            color: "white"
            border.width: mochi._stroke * 0.8
            border.color: mochi.lineColor
          }
        }
      }
    }
  }
}
