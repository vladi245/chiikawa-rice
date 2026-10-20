import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../theme/figures"

Item {
  id: view
  required property var controller

  readonly property color paper: "#fcf6e7"
  readonly property color line: "#4b302b"
  readonly property color dim: "#9c8273"
  readonly property color pink: "#e3708b"
  readonly property color blush: "#f6b4c1"
  readonly property color grass: "#c3e2a6"
  readonly property color errorColor: "#d65a5a"
  readonly property string display: "Nunito"
  readonly property string mono: "Maple Mono NF"

  property int typed: 0
  readonly property bool unlocking: controller.unlocking === true
  readonly property bool error: controller.error === true
  readonly property date now: controller.now

  readonly property string friendsMood: unlocking ? "happy" : (error ? "cry" : (controller.busy ? "wow" : "idle"))

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

  function weatherText(code) {
    if (code === 0) return "sunny";
    if (code <= 2) return "a few clouds";
    if (code === 3) return "cloudy";
    if (code <= 48) return "foggy";
    if (code <= 67) return "rainy";
    if (code <= 77) return "snowy";
    if (code <= 82) return "showers";
    if (code <= 86) return "snow showers";
    return "stormy";
  }

  readonly property string weatherLine: {
    const cur = weather?.weather?.current_weather;
    const parts = [];
    if (weather?.name)
      parts.push(weather.name.toLowerCase());
    if (cur)
      parts.push(`${Math.round(cur.temperature)}° and ${weatherText(cur.weathercode)}`);
    return parts.join("  ·  ");
  }

  readonly property string greeting: {
    const h = now.getHours();
    if (h < 5) return "it's late… sleepy time";
    if (h < 11) return "good morning!";
    if (h < 17) return "good afternoon!";
    if (h < 22) return "good evening!";
    return "almost bedtime~";
  }

  Rectangle {
    anchors.fill: parent
    color: view.paper
  }

  Item {
    id: wallpaper
    anchors.fill: parent
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
      asynchronous: true
      opacity: view.unlocking ? 0 : 0.85
      Behavior on opacity {
        NumberAnimation { duration: 900; easing.type: Easing.InOutCubic }
      }
    }
  }
  Rectangle {
    anchors.fill: parent
    color: view.paper
    opacity: view.unlocking ? 0 : 0.35
    Behavior on opacity {
      NumberAnimation { duration: 900; easing.type: Easing.InOutCubic }
    }
  }

  Repeater {
    model: view.unlocking ? 0 : 26
    delegate: Text {
      id: mote
      required property int index
      readonly property real seed: Math.abs(Math.sin(index * 12.9898) * 43758.5453) % 1
      readonly property real seed2: Math.abs(Math.sin(index * 78.233) * 12543.123) % 1
      text: index % 3 === 0 ? "✦" : (index % 3 === 1 ? "♥" : "•")
      color: index % 2 ? view.pink : "#e09a2f"
      font.pixelSize: 10 + seed2 * 10
      x: seed * view.width
      y: view.height
      opacity: 0
      SequentialAnimation {
        running: true
        loops: Animation.Infinite
        PauseAnimation { duration: mote.seed2 * 8000 }
        ParallelAnimation {
          NumberAnimation { target: mote; property: "y"; from: view.height + 20; to: -40; duration: 14000 + mote.seed * 9000 }
          SequentialAnimation {
            NumberAnimation { target: mote; property: "opacity"; from: 0; to: 0.7; duration: 1500 }
            PauseAnimation { duration: 9000 + mote.seed * 6000 }
            NumberAnimation { target: mote; property: "opacity"; to: 0; duration: 2500 }
          }
        }
      }
    }
  }

  Item {
    id: stage
    width: Math.min(parent.width - 48, 460)
    height: card.height + friends.peek
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -view.height * 0.04

    property real hop: 0
    property real drop: 0
    property real wobble: 0
    transform: [
      Rotation { origin.x: stage.width / 2; origin.y: stage.height; angle: stage.wobble },
      Translate { y: stage.hop + stage.drop }
    ]
    opacity: view.unlocking && stage.drop > view.height * 0.3 ? 0 : 1
    Behavior on opacity {
      NumberAnimation { duration: 200 }
    }

    CastFile {
      id: castFile
    }
    Item {
      id: friends
      readonly property var who: {
        const list = castFile.who("lock");
        return (Array.isArray(list) ? list : [list]).slice(0, 4);
      }
      readonly property real size: who.length > 3 ? 96 : 108
      readonly property real peek: size * 0.8
      width: parent.width
      height: size

      Repeater {
        model: friends.who.map((kind, i) => ({ "kind": kind, "x": (i + 0.5) / friends.who.length * 0.8 + 0.1, "delay": i * 90 }))
        delegate: Friend {
          id: friend
          required property var modelData
          width: friends.size
          x: friends.width * modelData.x - width / 2
          y: friends.size - width + rise
          kind: modelData.kind
          role: view.unlocking ? "happy" : ""
          mood: view.friendsMood !== "idle" ? view.friendsMood : (modelData.kind === "chiikawa" && view.typed > 0 ? "shy" : (modelData.kind === "usagi" && view.typed > 0 ? "happy" : "idle"))
          bobbing: view.unlocking

          property real rise: 0
          Connections {
            target: view
            function onTypedChanged() {
              if (view.typed > 0)
                peekUp.restart();
            }
            function onErrorChanged() {
              if (view.error)
                friend.boing();
            }
          }
          SequentialAnimation {
            id: peekUp
            PauseAnimation { duration: friend.modelData.delay * 0.5 }
            NumberAnimation { target: friend; property: "rise"; to: -6; duration: 90; easing.type: Easing.OutQuad }
            SpringAnimation { target: friend; property: "rise"; to: 0; spring: 6; damping: 0.25; epsilon: 0.1 }
          }
        }
      }
    }

    Rectangle {
      x: card.x + 7
      y: card.y + 8
      width: card.width
      height: card.height
      radius: card.radius
      color: Qt.alpha(view.line, 0.22)
    }

    Rectangle {
      id: card
      y: friends.peek
      width: parent.width
      height: column.implicitHeight + 64
      radius: 32
      color: view.paper
      border.width: 3
      border.color: view.line

      Item {
        id: patches
        anchors.fill: parent
        visible: false
        Rectangle { x: -30; y: card.height - 46; width: card.width * 0.55; height: 40; radius: 20; color: view.grass }
        Rectangle { x: card.width * 0.55; y: card.height - 36; width: card.width * 0.6; height: 36; radius: 18; color: view.grass }
      }
      MultiEffect {
        anchors.fill: parent
        anchors.margins: 3
        source: patches
        blurEnabled: true
        blur: 1
        blurMax: 32
        opacity: 0.6
        maskEnabled: true
        maskSource: cardMask
      }
      Item {
        id: cardMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle {
          anchors.fill: parent
          anchors.margins: 3
          radius: card.radius - 3
          color: "white"
        }
      }

      Column {
        id: column
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 30
        width: parent.width - 64
        spacing: 0

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: view.greeting
          color: view.pink
          font.family: view.display
          font.pixelSize: 17
          font.weight: Font.Black
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 4
          Text {
            text: Qt.formatTime(view.now, "HH")
            color: view.line
            font.family: view.display
            font.pixelSize: 96
            font.weight: Font.Black
          }
          Text {
            text: ":"
            color: view.pink
            opacity: view.now.getSeconds() % 2 ? 0.35 : 1
            font.family: view.display
            font.pixelSize: 96
            font.weight: Font.Black
            Behavior on opacity {
              NumberAnimation { duration: 300 }
            }
          }
          Text {
            text: Qt.formatTime(view.now, "mm")
            color: view.line
            font.family: view.display
            font.pixelSize: 96
            font.weight: Font.Black
          }
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: Qt.formatDate(view.now, "dddd, d MMMM").toLowerCase()
          color: view.dim
          font.family: view.display
          font.pixelSize: 16
          font.weight: Font.Bold
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          visible: view.weatherLine !== ""
          topPadding: 4
          text: view.weatherLine
          color: view.dim
          opacity: 0.8
          font.family: view.mono
          font.pixelSize: 11
        }

        Item {
          width: 1
          height: 26
        }

        Rectangle {
          id: field
          anchors.horizontalCenter: parent.horizontalCenter
          width: 280
          height: 46
          radius: height / 2
          color: "#fffdf8"
          border.width: 2.5
          border.color: view.error ? view.errorColor : (passwordInput.activeFocus ? view.pink : view.line)
          Behavior on border.color {
            ColorAnimation { duration: 200 }
          }

          TextInput {
            id: passwordInput
            anchors.fill: parent
            color: "transparent"
            selectionColor: "transparent"
            selectedTextColor: "transparent"
            cursorVisible: false
            cursorDelegate: Item {}
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
            spacing: 4
            Repeater {
              model: Math.min(view.typed, 14)
              delegate: Text {
                text: "♥"
                color: view.error ? view.errorColor : (index % 2 ? view.pink : view.blush)
                font.pixelSize: 17
                scale: 0.2
                Component.onCompleted: pop.start()
                NumberAnimation on scale {
                  id: pop
                  running: false
                  to: 1
                  duration: 260
                  easing.type: Easing.OutBack
                  easing.overshoot: 2.4
                }
              }
            }
          }

          Text {
            anchors.centerIn: parent
            visible: view.typed === 0
            text: "password, please"
            color: view.dim
            font.family: view.display
            font.pixelSize: 15
            font.weight: Font.Bold
          }
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          topPadding: 12
          text: view.unlocking ? "ya-ha! welcome back" : (view.error ? "uuu… that's not it" : (view.controller.busy ? "checking…" : "press enter to unlock"))
          color: view.error ? view.errorColor : view.dim
          font.family: view.display
          font.pixelSize: 13
          font.weight: Font.Bold
        }
      }
    }

    SequentialAnimation {
      id: nope
      NumberAnimation { target: stage; property: "wobble"; to: -3; duration: 60 }
      NumberAnimation { target: stage; property: "wobble"; to: 2.6; duration: 90 }
      NumberAnimation { target: stage; property: "wobble"; to: -1.6; duration: 80 }
      NumberAnimation { target: stage; property: "wobble"; to: 0.8; duration: 70 }
      NumberAnimation { target: stage; property: "wobble"; to: 0; duration: 60 }
    }
    SequentialAnimation {
      id: yay
      NumberAnimation { target: stage; property: "hop"; to: -36; duration: 200; easing.type: Easing.OutQuad }
      NumberAnimation { target: stage; property: "hop"; to: 0; duration: 180; easing.type: Easing.InQuad }
      NumberAnimation { target: stage; property: "drop"; to: view.height; duration: 520; easing.type: Easing.InBack }
    }

    Connections {
      target: view.controller
      function onErrorChanged() {
        if (view.controller.error)
          nope.restart();
      }
      function onBusyChanged() {
        if (!view.controller.busy)
          Qt.callLater(passwordInput.forceActiveFocus);
      }
      function onUnlockingChanged() {
        if (view.controller.unlocking)
          yay.restart();
        else {
          yay.stop();
          stage.hop = 0;
          stage.drop = 0;
        }
      }
    }
  }
}
