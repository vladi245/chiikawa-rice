import QtQuick
import QtQuick.Shapes

Item {
  id: hero

  property var sink: null
  property real volume: 0
  property bool muted: false
  property bool playing: false
  property string deviceName: ""
  signal toggleMute

  readonly property string nodeText: ((sink?.name || "") + " " + (sink?.description || "") + " " + (sink?.nickname || "")).toLowerCase()
  readonly property var props: sink?.properties || ({})

  readonly property string gear: {
    const t = nodeText;
    if ((props["device.api"] || "") === "bluez5" || t.startsWith("bluez"))
      return /bud|pods|earbud|wf-|tws/.test(t) ? "earbuds" : "wireless";
    if (/hdmi|displayport|\bdp\b/.test(t))
      return "screen";
    if (/headphone/.test(t))
      return "headphones";
    if (/headset|usb/.test(t) || props["device.bus"] === "usb")
      return "headset";
    return "speaker";
  }
  readonly property string gearLabel: ({
                                         "earbuds": "earbuds",
                                         "wireless": "bluetooth headphones",
                                         "screen": "monitor speakers",
                                         "headphones": "wired headphones",
                                         "headset": "usb headset",
                                         "speaker": "laptop speakers"
                                       })[gear]
  readonly property bool onSpeakers: gear === "screen" || gear === "speaker"

  readonly property var gearColors: ["#f2a0b4", "#79a9d1", "#f3cf6b", "#8fc56c", "#b9a3e3", "#f5a66b"]
  readonly property color gearColor: {
    const s = sink?.name || "";
    let h = 0;
    for (let i = 0; i < s.length; i++)
      h = (h * 31 + s.charCodeAt(i)) >>> 0;
    return gearColors[h % gearColors.length];
  }

  readonly property string mood: muted ? "shy" : (volume >= 0.92 ? "wow" : (playing ? "happy" : "idle"))

  CastFile {
    id: castFile
  }
  readonly property string who: castFile.who("sound")
  readonly property bool dancing: playing && !muted && castFile.has(who, "dance")

  width: parent ? parent.width : 0
  height: Theme.size(150)

  onGearChanged: face.boing()

  Rectangle {
    id: stage
    anchors.fill: parent
    radius: Theme.size(22)
    color: Theme.white
    border.width: 1.5
    border.color: Theme.line
    clip: true

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: Qt.alpha(Theme.line, 0.35)
        strokeWidth: 1.2
        fillColor: Qt.alpha(Theme.grass, 0.7)
        PathSvg {
          path: {
            const w = stage.width, h = stage.height, top = h - Theme.size(26);
            return `M 0 ${h} L 0 ${top + 8} Q ${w * 0.3} ${top - 8} ${w * 0.55} ${top + 2} Q ${w * 0.8} ${top + 10} ${w} ${top} L ${w} ${h} Z`;
          }
        }
      }
    }

    Repeater {
      model: hero.onSpeakers ? 2 : 0
      delegate: Rectangle {
        id: box
        required property int index
        readonly property real pulse: hero.playing && !hero.muted ? beat.level * Math.min(1, hero.volume) : 0
        width: Theme.size(hero.gear === "screen" ? 30 : 24)
        height: width * 1.45
        radius: Theme.size(6)
        color: hero.gearColor
        border.width: 1.5
        border.color: Theme.line
        x: face.x + (index === 0 ? -width - Theme.size(10) : face.width + Theme.size(10))
        y: stage.height - Theme.size(22) - height
        Repeater {
          model: 2
          delegate: Rectangle {
            required property int index
            readonly property real d: box.width * (index === 0 ? 0.62 : 0.34) * (1 + box.pulse * 0.18)
            width: d
            height: d
            radius: d / 2
            x: (box.width - d) / 2
            y: (index === 0 ? box.height * 0.62 : box.height * 0.24) - d / 2
            color: Theme.white
            border.width: 1.2
            border.color: Theme.line
          }
        }
      }
    }

    Friend {
      id: face
      width: Theme.size(96)
      x: hero.onSpeakers ? Theme.size(56) : Theme.size(26)
      y: stage.height - Theme.size(18) - width
      kind: hero.who
      role: hero.dancing ? "dance" : ""
      mood: hero.mood
      bobbing: hero.playing && !hero.muted
      headgear: hero.onSpeakers || hero.dancing ? "none" : (hero.gear === "wireless" ? "wireless" : hero.gear)
      gearColor: hero.gearColor
      animated: Theme.fx

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          face.boing();
          hero.toggleMute();
        }
      }
    }

    Repeater {
      model: hero.playing && !hero.muted && Theme.fx ? Math.max(1, Math.round(hero.volume * 4)) : 0
      delegate: Text {
        id: note
        required property int index
        text: index % 2 ? "♪" : "♫"
        color: index % 3 === 0 ? Theme.pink : (index % 3 === 1 ? Theme.hachiware : Theme.honey)
        font.pixelSize: Theme.size(14)
        font.weight: Font.Black
        x: face.x + face.width * (index % 2 ? 0.95 : 0.0)
        opacity: 0
        SequentialAnimation on y {
          loops: Animation.Infinite
          PauseAnimation { duration: note.index * 380 }
          NumberAnimation { from: face.y + face.height * 0.4; to: face.y - Theme.size(6); duration: 1500; easing.type: Easing.OutQuad }
        }
        SequentialAnimation on opacity {
          loops: Animation.Infinite
          PauseAnimation { duration: note.index * 380 }
          NumberAnimation { from: 0; to: 1; duration: 300 }
          NumberAnimation { to: 0; duration: 1200 }
        }
      }
    }

    Rectangle {
      id: bubble
      anchors.right: parent.right
      anchors.rightMargin: Theme.size(14)
      anchors.top: parent.top
      anchors.topMargin: Theme.size(16)
      width: Math.min(parent.width - face.x - face.width - Theme.size(40), Math.max(title.implicitWidth, sub.implicitWidth) + Theme.size(24))
      height: words.implicitHeight + Theme.size(16)
      radius: Theme.size(14)
      color: Theme.paper
      border.width: 1.5
      border.color: Theme.line

      Column {
        id: words
        anchors.centerIn: parent
        width: parent.width - Theme.size(20)
        spacing: Theme.size(2)
        Text {
          id: title
          width: parent.width
          text: hero.muted ? "shh… muted" : (hero.playing ? "listening on" : "ready on")
          elide: Text.ElideRight
          font.family: Theme.display
          font.pointSize: 9
          font.weight: Font.ExtraBold
          color: hero.muted ? Theme.inkFaint : Theme.pink
        }
        Text {
          width: parent.width
          text: hero.deviceName
          elide: Text.ElideRight
          font.family: Theme.display
          font.pointSize: 11
          font.weight: Font.Black
          color: Theme.ink
        }
        Text {
          id: sub
          width: parent.width
          text: hero.gearLabel + "  ·  " + Math.round(hero.volume * 100) + "%"
          elide: Text.ElideRight
          font.family: Theme.font
          font.pointSize: 7.5
          color: Theme.inkSoft
        }
      }
    }

    Text {
      anchors.right: parent.right
      anchors.rightMargin: Theme.size(16)
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Theme.size(6)
      text: "tap " + (castFile.names[hero.who] ?? "them").toLowerCase() + " to " + (hero.muted ? "unmute" : "mute")
      font.family: Theme.font
      font.pointSize: 7
      color: Theme.inkSoft
    }
  }

  QtObject {
    id: beat
    property real level: 0
  }
  SequentialAnimation {
    running: Theme.fx && hero.playing && !hero.muted && hero.visible
    loops: Animation.Infinite
    NumberAnimation { target: beat; property: "level"; to: 1; duration: 120; easing.type: Easing.OutQuad }
    NumberAnimation { target: beat; property: "level"; to: 0; duration: 340; easing.type: Easing.InQuad }
  }
}
