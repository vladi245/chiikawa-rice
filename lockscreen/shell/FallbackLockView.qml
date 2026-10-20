import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io

Item {
  id: view
  required property var controller
  readonly property color fg: Quickshell.env("WOODLAND_LOCK_FG") || "#e2e2e2"
  readonly property color dim: Quickshell.env("WOODLAND_LOCK_DIM") || "#c6c6c6"
  readonly property color accent: Quickshell.env("WOODLAND_LOCK_ACCENT") || "#A6A08C"
  readonly property color warm: "#ebdfd1"
  readonly property color errorColor: "#c87f6e"
  readonly property string font: "JetBrainsMono Nerd Font"

  property int typed: 0
  readonly property bool unlocking: controller.unlocking === true
  readonly property date now: controller.now

  property var weather: null
  FileView {
    path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/noctalia/location.json"
    onLoaded: {
      try {
        view.weather = JSON.parse(text());
      } catch (e) {
        view.weather = null;
      }
    }
  }

  readonly property int minute: Math.floor(now.getTime() / 60000)

  function dayTimes(offset) {
    const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() + offset);
    const daily = weather?.weather?.daily;
    if (daily?.time?.length) {
      let best = 0, bestGap = Infinity;
      for (let i = 0; i < daily.time.length; i++) {
        const gap = Math.round((d - new Date(daily.time[i] + "T00:00")) / 86400000);
        if (Math.abs(gap) < Math.abs(bestGap)) {
          best = i;
          bestGap = gap;
        }
      }
      const shift = bestGap * 86400000;
      return { "rise": new Date(new Date(daily.sunrise[best]).getTime() + shift), "set": new Date(new Date(daily.sunset[best]).getTime() + shift) };
    }
    return { "rise": new Date(d.getTime() + 6 * 3600000), "set": new Date(d.getTime() + 18 * 3600000) };
  }

  readonly property var sky: {
    minute;
    const t0 = dayTimes(0);
    const n = now.getTime();
    if (n >= t0.rise && n < t0.set)
      return { "isDay": true, "from": t0.rise, "to": t0.set, "t": (n - t0.rise) / (t0.set - t0.rise) };
    const from = n < t0.rise ? dayTimes(-1).set : t0.set;
    const to = n < t0.rise ? t0.rise : dayTimes(1).rise;
    return { "isDay": false, "from": from, "to": to, "t": (n - from) / (to - from) };
  }

  readonly property real moonPhase: {
    minute;
    const synodic = 29.530588853;
    const ref = Date.UTC(2000, 0, 6, 18, 14);
    const p = ((now.getTime() - ref) / 86400000 / synodic) % 1;
    return p < 0 ? p + 1 : p;
  }

  function span(ms) {
    const m = Math.max(0, Math.round(ms / 60000));
    return m >= 60 ? `${Math.floor(m / 60)}h ${m % 60}m` : `${m}m`;
  }

  function weatherText(code) {
    if (code === 0) return "clear";
    if (code <= 2) return "partly cloudy";
    if (code === 3) return "overcast";
    if (code <= 48) return "fog";
    if (code <= 57) return "drizzle";
    if (code <= 67) return "rain";
    if (code <= 77) return "snow";
    if (code <= 82) return "showers";
    if (code <= 86) return "snow showers";
    return "thunderstorm";
  }

  readonly property string skyLine: {
    minute;
    const parts = [];
    if (weather?.name)
      parts.push(weather.name.toLowerCase());
    const cur = weather?.weather?.current_weather;
    if (cur)
      parts.push(`${Math.round(cur.temperature)}° ${weatherText(cur.weathercode)}`);
    const left = sky.to.getTime() - now.getTime();
    parts.push(sky.isDay ? `${span(left)} of daylight left` : `sunrise in ${span(left)}`);
    return parts.join("   ·   ");
  }

  Rectangle {
    anchors.fill: parent
    color: "#0c0d0a"
  }

  Item {
    anchors.fill: parent
    SequentialAnimation on scale {
      loops: Animation.Infinite
      running: !view.unlocking
      NumberAnimation { from: 1.0; to: 1.06; duration: 45000; easing.type: Easing.InOutSine }
      NumberAnimation { from: 1.06; to: 1.0; duration: 45000; easing.type: Easing.InOutSine }
    }

    Image {
      anchors.fill: parent
      source: Quickshell.env("WOODLAND_LOCK_SHARP") || ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
    }
    Image {
      anchors.fill: parent
      source: Quickshell.env("WOODLAND_LOCK_BG") || ""
      fillMode: Image.PreserveAspectCrop
      smooth: true
      opacity: view.unlocking ? 0 : 1
      Behavior on opacity {
        NumberAnimation { duration: 900; easing.type: Easing.InOutCubic }
      }
    }
  }
  Rectangle {
    anchors.fill: parent
    opacity: view.unlocking ? 0.15 : 1
    gradient: Gradient {
      GradientStop { position: 0.0; color: Qt.alpha("#0c0d0a", 0.55) }
      GradientStop { position: 0.6; color: Qt.alpha("#0c0d0a", 0.4) }
      GradientStop { position: 1.0; color: Qt.alpha("#0c0d0a", 0.7) }
    }
    Behavior on opacity {
      NumberAnimation { duration: 900; easing.type: Easing.InOutCubic }
    }
  }

  Item {
    id: ridge
    anchors.fill: parent
    transform: Translate {
      y: view.unlocking ? view.height * 0.3 : 0
      Behavior on y {
        NumberAnimation { duration: 900; easing.type: Easing.InCubic }
      }
    }

    Repeater {
      model: [
        { "height": 0.26, "color": "#2b2d25", "seed": 7, "count": 44, "edge": 1.0 },
        { "height": 0.34, "color": "#121310", "seed": 19, "count": 24, "edge": 1.1 }
      ]
      delegate: Shape {
        id: forest
        required property var modelData
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeWidth: 0
          strokeColor: "transparent"
          fillColor: forest.modelData.color
          fillRule: ShapePath.WindingFill
          PathSvg {
            path: {
              const w = view.width, h = view.height, m = forest.modelData;
              if (w <= 0 || h <= 0)
                return "";
              let seed = m.seed;
              const rand = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
              const base = h * 1.01;
              const scale = h * m.height;
              let d = "";
              for (let i = 0; i < m.count; i++) {
                const cx = (i + 0.2 + rand() * 0.6) / m.count * w;
                const edge = Math.pow(Math.abs(cx / w - 0.5) * 2, 2);
                const th = scale * (0.35 + rand() * 0.35) * (0.45 + edge * m.edge);
                const half = th * (0.17 + rand() * 0.05);
                const top = base - th;
                const leftEdge = [];
                for (let t = 1; t <= 5; t++) {
                  const y = top + th * 0.92 * t / 5;
                  const outer = half * t / 5;
                  leftEdge.push([cx - outer, y], [cx - outer * 0.55, y - th * 0.05]);
                }
                leftEdge.push([cx - half * 0.12, base]);
                const outline = [[cx, top]].concat(leftEdge, leftEdge.slice().reverse().map(([x, y]) => [2 * cx - x, y]));
                d += " M " + outline.map(([x, y]) => `${x.toFixed(1)} ${y.toFixed(1)}`).join(" L ") + " Z";
              }
              return d;
            }
          }
        }
      }
    }

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: view.height * 0.05
      color: "#121310"
      Text {
        anchors.centerIn: parent
        text: view.skyLine
        color: view.dim
        opacity: 0.6
        font.family: view.font
        font.pixelSize: 11
        font.letterSpacing: 1.5
      }
    }
  }

  Item {
    id: dial
    readonly property real r: Math.round(Math.min(view.width * 0.07, 120))
    readonly property real t: Math.max(0, Math.min(1, view.sky.t))
    readonly property color line: view.sky.isDay ? view.warm : view.accent
    width: r * 2
    height: r
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: view.height * 0.05 + 44
    opacity: view.unlocking ? 0 : 1
    Behavior on opacity {
      NumberAnimation { duration: 400 }
    }

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: Qt.alpha(dial.line, 0.18)
        strokeWidth: 1
        fillColor: "transparent"
        PathAngleArc { centerX: dial.r; centerY: dial.r; radiusX: dial.r; radiusY: dial.r; startAngle: 180; sweepAngle: 180 }
      }
      ShapePath {
        strokeColor: Qt.alpha(dial.line, 0.7)
        strokeWidth: 1.5
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: dial.r; centerY: dial.r; radiusX: dial.r; radiusY: dial.r; startAngle: 180; sweepAngle: 180 * dial.t }
      }
    }

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.bottom
      width: parent.width + 56
      height: 1
      color: Qt.alpha(view.fg, 0.25)
    }

    Item {
      id: body
      readonly property real angle: Math.PI * (1 + dial.t)
      width: 22
      height: 22
      x: dial.r + dial.r * Math.cos(angle) - width / 2
      y: dial.r + dial.r * Math.sin(angle) - height / 2

      Rectangle {
        visible: view.sky.isDay
        anchors.centerIn: parent
        width: 12
        height: 12
        radius: 6
        color: view.warm
      }

          Canvas {
            id: moon
            visible: !view.sky.isDay
            anchors.centerIn: parent
            width: 20
            height: 20
            property real phase: view.moonPhase
            onPhaseChanged: requestPaint()
            onPaint: {
              const ctx = getContext("2d");
              ctx.reset();
              const r = width / 2 - 0.5, cx = width / 2, cy = height / 2;
              ctx.fillStyle = Qt.alpha(view.accent, 0.18);
              ctx.strokeStyle = Qt.alpha(view.warm, 0.4);
              ctx.lineWidth = 1;
              ctx.beginPath();
              ctx.arc(cx, cy, r, 0, Math.PI * 2);
              ctx.fill();
              ctx.stroke();

              const waxing = phase < 0.5;
              const s = waxing ? 1 : -1;
              const k = Math.cos(2 * Math.PI * phase);
              ctx.fillStyle = view.warm;
              ctx.beginPath();
              ctx.moveTo(cx, cy - r);
              ctx.arc(cx, cy, r, -Math.PI / 2, Math.PI / 2, !waxing);
              for (let i = 0; i <= 32; i++) {
                const dy = r - 2 * r * i / 32;
                ctx.lineTo(cx + s * r * k * Math.sqrt(Math.max(0, 1 - dy * dy / (r * r))), cy + dy);
              }
              ctx.closePath();
              ctx.fill();
            }
          }
    }

    Repeater {
      model: [
        { "time": view.sky.from, "left": true },
        { "time": view.sky.to, "left": false }
      ]
      delegate: Text {
        required property var modelData
        anchors.top: parent.bottom
        anchors.topMargin: 8
        x: modelData.left ? -width / 2 : dial.width - width / 2
        text: Qt.formatTime(modelData.time, "HH:mm")
        color: view.dim
        opacity: 0.55
        font.family: view.font
        font.pixelSize: 11
        font.letterSpacing: 1
      }
    }
  }

  ColumnLayout {
    id: content
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: -view.height * 0.12 + (view.unlocking ? -60 : 0)
    width: Math.min(parent.width - 48, 460)
    spacing: 0
    opacity: view.unlocking ? 0 : 1
    Behavior on anchors.verticalCenterOffset {
      NumberAnimation { duration: 700; easing.type: Easing.InCubic }
    }
    Behavior on opacity {
      NumberAnimation { duration: 500 }
    }

    readonly property int clockSize: Math.round(Math.min(view.height * 0.15, 180))

    Row {
      id: clock
      Layout.alignment: Qt.AlignHCenter
      spacing: Math.round(content.clockSize * 0.12)
      Text {
        text: Qt.formatTime(view.now, "HH")
        color: view.fg
        font.family: view.font
        font.pixelSize: content.clockSize
        font.weight: Font.ExtraBold
        font.letterSpacing: -content.clockSize * 0.04
      }
      Text {
        text: Qt.formatTime(view.now, "mm")
        color: view.accent
        font.family: view.font
        font.pixelSize: content.clockSize
        font.weight: Font.Thin
        font.letterSpacing: -content.clockSize * 0.04
      }
    }

    Item {
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: -Math.round(content.clockSize * 0.08)
      width: clock.width
      height: 1
      Rectangle {
        anchors.fill: parent
        color: Qt.alpha(view.fg, 0.15)
      }
      Rectangle {
        id: secondsFill
        height: 1
        color: view.fg
        opacity: 0.7
        width: parent.width * view.now.getSeconds() / 59
        Behavior on width {
          enabled: secondsFill.width > 0
          NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }
      }
    }

    Text {
      Layout.fillWidth: true
      Layout.topMargin: 16
      text: Qt.formatDate(view.now, "dddd  ·  d MMMM").toUpperCase()
      color: view.dim
      opacity: 0.8
      font.family: view.font
      font.pixelSize: 13
      font.letterSpacing: 4
      horizontalAlignment: Text.AlignHCenter
    }

    Item {
      id: field
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: 44
      width: 280
      height: 40
      transform: Translate {
        id: shake
      }

      TextInput {
        id: passwordInput
        anchors.fill: parent
        color: "transparent"
        selectionColor: "transparent"
        selectedTextColor: "transparent"
        cursorVisible: false
        cursorDelegate: Item {}
        font.family: view.font
        font.pixelSize: 18
        echoMode: TextInput.Password
        enabled: !view.controller.busy && !view.unlocking
        verticalAlignment: TextInput.AlignVCenter
        onTextChanged: view.typed = text.length
        onAccepted: {
          view.controller.submit(text);
          text = "";
        }
        Component.onCompleted: Qt.callLater(forceActiveFocus)
      }

      Row {
        anchors.centerIn: parent
        spacing: 10
        Repeater {
          model: Math.min(view.typed, 18)
          delegate: Rectangle {
            width: 6
            height: 6
            radius: 3
            color: view.controller.error ? view.errorColor : view.fg
            scale: 0.2
            Component.onCompleted: pop.start()
            NumberAnimation on scale {
              id: pop
              running: false
              to: 1
              duration: 180
              easing.type: Easing.OutBack
            }
          }
        }
      }

      Text {
        anchors.centerIn: parent
        text: "password"
        color: view.dim
        opacity: 0.45
        font.family: view.font
        font.pixelSize: 13
        font.letterSpacing: 2
        visible: view.typed === 0
      }

      Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: passwordInput.activeFocus ? parent.width : parent.width * 0.4
        height: 1
        color: view.controller.error ? view.errorColor : (passwordInput.activeFocus ? view.accent : Qt.alpha(view.fg, 0.3))
        Behavior on width {
          NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
      }

      Connections {
        target: view.controller
        function onBusyChanged() {
          if (!view.controller.busy)
            Qt.callLater(passwordInput.forceActiveFocus);
        }
        function onErrorChanged() {
          if (view.controller.error)
            nope.restart();
        }
      }

      SequentialAnimation {
        id: nope
        NumberAnimation { target: shake; property: "x"; to: -10; duration: 50 }
        NumberAnimation { target: shake; property: "x"; to: 9; duration: 70 }
        NumberAnimation { target: shake; property: "x"; to: -6; duration: 60 }
        NumberAnimation { target: shake; property: "x"; to: 3; duration: 50 }
        NumberAnimation { target: shake; property: "x"; to: 0; duration: 50 }
      }
    }

    Text {
      Layout.fillWidth: true
      Layout.topMargin: 14
      text: view.controller.status || "enter to unlock"
      color: view.controller.error ? "#ffb4ab" : view.dim
      opacity: view.controller.error ? 1 : 0.5
      font.family: view.font
      font.pixelSize: 11
      font.letterSpacing: 2
      horizontalAlignment: Text.AlignHCenter
    }
  }
}
