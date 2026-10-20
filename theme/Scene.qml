import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

Item {
  id: scene

  property bool sky: true
  property bool sparkles: true
  property int density: Math.round(width * height / 7000)
  property bool clouds: true
  property bool grass: true
  property real grassScale: 1.0
  property bool running: Theme.fx && visible

  readonly property int sparkleCount: Math.min(36, Math.max(6, Math.round(density * 0.4)))

  clip: true

  function rng(seed) {
    let s = seed;
    return () => (s = (s * 16807) % 2147483647) / 2147483647;
  }

  Rectangle {
    anchors.fill: parent
    visible: scene.sky
    gradient: Gradient {
      GradientStop { position: 0.0; color: Theme.paper }
      GradientStop { position: 1.0; color: Theme.cream }
    }
  }

  Item {
    id: patches
    anchors.fill: parent
    visible: false
    Repeater {
      model: scene.sky ? [
        { "x": -0.08, "y": 0.04, "w": 0.42, "h": 0.12 },
        { "x": 0.68, "y": 0.16, "w": 0.4, "h": 0.1 },
        { "x": 0.1, "y": 0.46, "w": 0.34, "h": 0.09 },
        { "x": 0.62, "y": 0.58, "w": 0.46, "h": 0.12 },
        { "x": -0.1, "y": 0.8, "w": 0.5, "h": 0.14 }
      ] : []
      delegate: Rectangle {
        required property var modelData
        x: scene.width * modelData.x
        y: scene.height * modelData.y
        width: scene.width * modelData.w
        height: Math.max(18, scene.height * modelData.h)
        radius: height / 2
        color: Theme.grass
        opacity: 0.55
      }
    }
  }
  MultiEffect {
    anchors.fill: parent
    visible: scene.sky
    source: patches
    blurEnabled: true
    blur: 1
    blurMax: 48
  }

  Shape {
    anchors.fill: parent
    visible: scene.grass
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: Qt.alpha(Theme.line, 0.32)
      strokeWidth: 1.3
      capStyle: ShapePath.RoundCap
      fillColor: "transparent"
      PathSvg {
        path: {
          const w = scene.width, h = scene.height;
          if (w <= 0 || h <= 0)
            return "";
          const rand = scene.rng(23);
          const n = Math.max(4, Math.round(w * h / 16000));
          const s = 7 * scene.grassScale;
          let d = "";
          for (let i = 0; i < n; i++) {
            const x = rand() * w, y = h * 0.12 + rand() * h * 0.86;
            for (let k = -1; k <= 1; k++)
              d += ` M ${(x + k * s * 0.55).toFixed(1)} ${y.toFixed(1)} L ${(x + k * s * 0.75 + s * 0.15).toFixed(1)} ${(y - s * (k === 0 ? 1.15 : 0.9)).toFixed(1)}`;
          }
          return d;
        }
      }
    }
  }

  Shape {
    anchors.fill: parent
    visible: scene.grass
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: Qt.alpha(Theme.line, 0.25)
      strokeWidth: 1.2
      fillColor: Qt.alpha(Theme.grass, 0.55)
      PathSvg {
        path: {
          const w = scene.width, h = scene.height;
          if (w <= 0 || h <= 0)
            return "";
          const top = h - Math.min(28, h * 0.08) * scene.grassScale;
          return `M 0 ${h + 2} L 0 ${top + 6} Q ${w * 0.25} ${top - 6} ${w * 0.5} ${top + 2} Q ${w * 0.75} ${top + 10} ${w} ${top - 2} L ${w} ${h + 2} Z`;
        }
      }
    }
  }

  Repeater {
    model: scene.clouds ? [{ "y": 0.05, "s": 1.0, "d": 70000, "from": 0.15 }, { "y": 0.15, "s": 0.7, "d": 95000, "from": 0.7 }] : []
    delegate: Shape {
      id: cloud
      required property var modelData
      width: 46 * modelData.s
      height: 20 * modelData.s
      y: scene.height * modelData.y
      x: scene.width * modelData.from
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: Qt.alpha(Theme.line, 0.55)
        strokeWidth: 1.2
        fillColor: Theme.white
        joinStyle: ShapePath.RoundJoin
        PathSvg {
          path: {
            const w = cloud.width, h = cloud.height;
            return `M ${w * 0.12} ${h} Q 0 ${h} ${w * 0.06} ${h * 0.62} Q ${w * 0.1} ${h * 0.3} ${w * 0.3} ${h * 0.42} Q ${w * 0.36} 0 ${w * 0.58} ${h * 0.14} Q ${w * 0.76} ${h * 0.02} ${w * 0.84} ${h * 0.46} Q ${w} ${h * 0.5} ${w * 0.94} ${h} Z`;
          }
        }
      }
      NumberAnimation on x {
        running: scene.running
        loops: Animation.Infinite
        from: -cloud.width
        to: scene.width + cloud.width
        duration: cloud.modelData.d
      }
    }
  }

  Repeater {
    model: scene.sparkles && scene.running ? scene.sparkleCount : 0
    delegate: Item {
      id: mote
      required property int index
      readonly property real seed: Math.abs(Math.sin(index * 12.9898) * 43758.5453) % 1
      readonly property real seed2: Math.abs(Math.sin(index * 78.233) * 12543.123) % 1
      readonly property bool star: index % 3 === 0
      readonly property real baseX: seed * scene.width
      width: star ? 9 : 4 + seed2 * 3
      height: width
      x: baseX
      y: scene.height
      opacity: 0

      Text {
        visible: mote.star
        anchors.centerIn: parent
        text: "✦"
        font.pixelSize: mote.width * 1.3
        color: mote.seed2 > 0.5 ? Theme.pink : Theme.honey
      }
      Rectangle {
        visible: !mote.star
        anchors.fill: parent
        radius: width / 2
        color: mote.seed2 > 0.4 ? Theme.blush : Theme.grass
      }

      SequentialAnimation {
        running: true
        loops: Animation.Infinite
        PauseAnimation { duration: mote.seed2 * 6000 }
        ParallelAnimation {
          NumberAnimation { target: mote; property: "y"; from: scene.height + 10; to: -20; duration: 9000 + mote.seed * 7000 }
          SequentialAnimation {
            NumberAnimation { target: mote; property: "opacity"; from: 0; to: 0.85; duration: 1200 }
            PauseAnimation { duration: 5000 + mote.seed * 5000 }
            NumberAnimation { target: mote; property: "opacity"; to: 0; duration: 2000 }
          }
        }
      }
      SequentialAnimation on x {
        running: true
        loops: Animation.Infinite
        NumberAnimation { from: mote.baseX - 8; to: mote.baseX + 8; duration: 2200 + mote.seed * 1400; easing.type: Easing.InOutSine }
        NumberAnimation { from: mote.baseX + 8; to: mote.baseX - 8; duration: 2200 + mote.seed * 1400; easing.type: Easing.InOutSine }
      }
    }
  }
}
