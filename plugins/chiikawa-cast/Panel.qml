import QtQuick
import "../../chiikawa"

WPanel {
  id: root

  contentPreferredWidth: Woodland.size(420)
  contentPreferredHeight: Woodland.size(585)
  scene.rainCount: 20

  CastFile {
    id: castFile
  }

  readonly property var places: [
    { "key": "pet", "title": "desktop pet", "hint": "walks along the bottom of the screen", "icon": "paw", "nobody": true },
    { "key": "sound", "title": "sound panel", "hint": "dances while music plays", "icon": "headphones" },
    { "key": "launcher", "title": "launcher", "hint": "peeks out of the search field", "icon": "search" },
    { "key": "lock", "title": "lock screen", "hint": "pick up to four", "icon": "lock", "many": true }
  ]

  function picked(place, kind) {
    const v = castFile.who(place.key);
    return place.many ? (Array.isArray(v) ? v : [v]).indexOf(kind) >= 0 : v === kind;
  }

  function pick(place, kind) {
    if (!place.many) {
      castFile.set(place.key, kind);
      return;
    }
    const v = castFile.who(place.key);
    let list = (Array.isArray(v) ? v : [v]).slice();
    if (list.indexOf(kind) >= 0) {
      if (list.length > 1)
        list = list.filter(k => k !== kind);
    } else if (list.length < 4) {
      list.push(kind);
    }
    castFile.set(place.key, castFile.kinds.filter(k => list.indexOf(k) >= 0));
  }

  Header {
    icon: "users"
    title: "Cast"
    subtitle: "who shows up where"
    lit: true
  }

  Item {
    width: 1
    height: Woodland.size(2)
  }

  Repeater {
    model: root.places
    delegate: Column {
      id: section
      required property var modelData
      width: parent.width
      spacing: Woodland.size(6)

      Row {
        spacing: Woodland.size(8)
        Text {
          text: section.modelData.title
          font.family: Woodland.display
          font.pointSize: 10.5
          font.weight: Font.ExtraBold
          color: Woodland.mist
        }
        Text {
          anchors.baseline: parent.children[0].baseline
          text: section.modelData.hint
          font.family: Woodland.font
          font.pointSize: 7.5
          color: Woodland.bark
        }
      }

      Row {
        spacing: Woodland.size(6)

        Repeater {
          model: section.modelData.nobody ? castFile.kinds.concat(["none"]) : castFile.kinds
          delegate: Rectangle {
            id: card
            required property string modelData
            readonly property bool chosen: root.picked(section.modelData, modelData)
            readonly property bool hot: cardHover.hovered

            width: Woodland.size(section.modelData.nobody ? 70 : 87)
            height: Woodland.size(86)
            radius: Woodland.size(16)
            color: chosen ? Woodland.blush : (hot ? Qt.alpha(Woodland.blush, 0.35) : Woodland.white)
            border.width: chosen ? 2 : 1.5
            border.color: chosen ? Woodland.line : Qt.alpha(Woodland.line, 0.45)
            scale: cardTap.pressed ? 0.94 : (hot ? 1.04 : 1)
            Behavior on scale {
              SpringAnimation { spring: 6; damping: 0.3; epsilon: 0.005 }
            }
            Behavior on color {
              ColorAnimation { duration: 160 }
            }

            Friend {
              id: face
              visible: card.modelData !== "none"
              anchors.horizontalCenter: parent.horizontalCenter
              y: Woodland.size(6)
              width: Woodland.size(56)
              kind: card.modelData === "none" ? "hachiware" : card.modelData
              role: card.chosen || card.hot ? "idle" : ""
              animated: Woodland.fx && root.visible
            }
            Text {
              visible: card.modelData === "none"
              anchors.horizontalCenter: parent.horizontalCenter
              y: Woodland.size(18)
              text: "z z"
              font.family: Woodland.display
              font.pointSize: 16
              font.weight: Font.Black
              color: Woodland.bark
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              anchors.bottomMargin: Woodland.size(6)
              text: card.modelData === "none" ? "nobody" : (castFile.names[card.modelData] ?? card.modelData).toLowerCase()
              font.family: Woodland.font
              font.pointSize: 7.5
              font.weight: card.chosen ? Font.Bold : Font.Normal
              color: card.chosen ? Woodland.line : Woodland.fog
            }
            Text {
              visible: card.chosen && section.modelData.many
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Woodland.size(4)
              text: "♥"
              font.pixelSize: Woodland.size(12)
              color: Woodland.windowLight
            }

            HoverHandler {
              id: cardHover
              cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
              id: cardTap
              onTapped: {
                root.pick(section.modelData, card.modelData);
                face.boing();
              }
            }
          }
        }
      }
    }
  }
}
