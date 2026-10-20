import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Widgets
import "../../chiikawa"

Item {
  id: card

  property string title: ""
  property string body: ""
  property string appName: ""
  property string image: ""
  property string glyph: ""        // tabler icon when there's no image
  property int urgency: 1          // 0 low, 1 normal, 2 critical
  property string kind: "notice"   // notice | warning | error (system toasts)
  property var actions: []         // [{ identifier, text }]
  property int duration: 8000      // ms, -1 = until dismissed
  property date timestamp: new Date()

  signal clicked
  signal dismissed
  signal action(string identifier)
  signal expired

  readonly property bool urgent: urgency === 2 || kind === "error"
  readonly property color accent: urgent ? Theme.honey : (kind === "warning" ? Theme.honey : Theme.pink)
  readonly property bool hovered: hover.hovered
  property real remaining: 1
  property bool leaving: false

  width: Theme.size(380)
  implicitHeight: content.implicitHeight + Theme.size(26)
  height: implicitHeight
  opacity: 0
  transform: Translate {
    id: slide
    x: Theme.size(40)
  }

  function leave(after) {
    if (leaving)
      return;
    leaving = true;
    outro.after = after;
    outro.start();
  }

  Component.onCompleted: intro.start()

  ParallelAnimation {
    id: intro
    NumberAnimation { target: card; property: "opacity"; to: 1; duration: Theme.fx ? 260 : 0; easing.type: Easing.OutCubic }
    NumberAnimation { target: slide; property: "x"; to: 0; duration: Theme.fx ? 420 : 0; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
    SequentialAnimation {
      PauseAnimation { duration: Theme.fx ? 140 : 0 }
      NumberAnimation { target: glow; property: "level"; from: 0; to: 1; duration: Theme.fx ? 500 : 0; easing.type: Easing.OutCubic }
    }
  }

  SequentialAnimation {
    id: outro
    property string after: "dismissed"
    ParallelAnimation {
      NumberAnimation { target: card; property: "opacity"; to: 0; duration: Theme.fx ? 220 : 0 }
      NumberAnimation { target: slide; property: "x"; to: Theme.size(60); duration: Theme.fx ? 260 : 0; easing.type: Easing.InCubic }
    }
    ScriptAction {
      script: outro.after === "expired" ? card.expired() : card.dismissed()
    }
  }

  Timer {
    running: card.duration > 0 && !card.hovered && !card.leaving
    interval: 50
    repeat: true
    onTriggered: {
      card.remaining = Math.max(0, card.remaining - interval / card.duration);
      if (card.remaining <= 0)
        card.leave("expired");
    }
  }

  QtObject {
    id: glow
    property real level: 0
  }

  Rectangle {
    id: background
    anchors.fill: parent
    radius: Theme.size(8)
    gradient: Gradient {
      GradientStop { position: 0.0; color: Theme.cream }
      GradientStop { position: 1.0; color: Theme.paper }
    }
    border.width: 1
    border.color: Qt.alpha(card.urgent ? Theme.honey : Theme.inkSoft, card.hovered ? 0.4 : 0.2)
    layer.enabled: Theme.fx
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: "#000000"
      shadowOpacity: 0.6
      shadowBlur: 0.8
      shadowVerticalOffset: 3
      shadowHorizontalOffset: 0
      blurMax: 24
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: background.radius
    opacity: glow.level * (card.hovered ? 1 : 0.75)
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: Qt.alpha(card.accent, 0.14) }
      GradientStop { position: 0.35; color: Qt.alpha(card.accent, 0.03) }
      GradientStop { position: 1.0; color: "transparent" }
    }
  }

  Rectangle {
    x: Theme.size(6)
    anchors.verticalCenter: parent.verticalCenter
    width: 2
    height: (parent.height - Theme.size(24)) * glow.level
    radius: 1
    color: card.accent
    layer.enabled: Theme.fx
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: card.accent
      shadowBlur: 1
      shadowOpacity: 0.9
      shadowHorizontalOffset: 0
      shadowVerticalOffset: 0
      blurMax: 18
    }
  }

  Column {
    id: content
    x: Theme.size(20)
    y: Theme.size(13)
    width: parent.width - Theme.size(34)
    spacing: Theme.size(6)

    Row {
      width: parent.width
      spacing: Theme.size(12)

      Item {
        id: iconBox
        width: Theme.size(34)
        height: width
        visible: card.image !== "" || card.glyph !== "" || card.appName !== ""

        Image {
          id: picture
          anchors.fill: parent
          source: card.image
          sourceSize: Qt.size(width * 2, height * 2)
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          visible: false
        }
        Rectangle {
          id: pictureMask
          anchors.fill: parent
          radius: Theme.size(6)
          visible: false
          layer.enabled: true
        }
        MultiEffect {
          anchors.fill: parent
          source: picture
          visible: picture.status === Image.Ready
          maskEnabled: true
          maskSource: pictureMask
          saturation: card.hovered ? 0 : -0.5
          Behavior on saturation {
            NumberAnimation { duration: 250 }
          }
        }
        Rectangle {
          anchors.fill: parent
          visible: picture.status !== Image.Ready
          radius: Theme.size(6)
          color: Qt.alpha(Theme.tan, 0.6)
          border.width: 1
          border.color: Qt.alpha(Theme.inkSoft, 0.25)
          NIcon {
            anchors.centerIn: parent
            visible: card.glyph !== ""
            icon: card.glyph || "point"
            pointSize: 14
            color: card.urgent || card.kind === "warning" ? Theme.honey : Theme.ink
          }
          Text {
            anchors.centerIn: parent
            visible: card.glyph === ""
            text: (card.appName || "?").charAt(0).toUpperCase()
            font.family: Theme.font
            font.pointSize: 13
            font.weight: Font.Bold
            color: Theme.ink
          }
        }
      }

      Column {
        width: parent.width - (iconBox.visible ? iconBox.width + parent.spacing : 0) - closeButton.width
        spacing: Theme.size(2)

        Text {
          width: parent.width
          visible: text !== ""
          text: card.appName ? `${card.appName.toLowerCase()}  ·  ${card.urgent ? "urgent  ·  " : ""}now` : ""
          elide: Text.ElideRight
          font.family: Theme.font
          font.pointSize: 7.5
          color: card.urgent ? Theme.honey : Theme.inkFaint
        }
        Text {
          width: parent.width
          text: card.title
          elide: Text.ElideRight
          maximumLineCount: 2
          wrapMode: Text.Wrap
          font.family: Theme.font
          font.pointSize: 10
          font.weight: Font.DemiBold
          color: card.urgent ? Theme.lit(Theme.honey, 0.3) : Theme.ink
        }
        Text {
          width: parent.width
          visible: text !== ""
          text: card.body
          wrapMode: Text.Wrap
          maximumLineCount: card.hovered ? 8 : 3
          elide: Text.ElideRight
          textFormat: Text.PlainText
          font.family: Theme.font
          font.pointSize: 8.5
          color: Theme.inkSoft
        }
      }

      Item {
        id: closeButton
        width: Theme.size(18)
        height: width
        opacity: card.hovered ? 1 : 0
        Behavior on opacity {
          NumberAnimation { duration: 150 }
        }
        NIcon {
          anchors.centerIn: parent
          icon: "x"
          pointSize: 10
          color: closeArea.containsMouse ? Theme.pink : Theme.inkSoft
        }
        MouseArea {
          id: closeArea
          anchors.fill: parent
          anchors.margins: -4
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: card.leave("dismissed")
        }
      }
    }

    Flow {
      width: parent.width
      visible: card.actions.length > 0
      spacing: Theme.size(6)
      leftPadding: iconBox.visible ? iconBox.width + Theme.size(12) : 0
      Repeater {
        model: card.actions
        delegate: CButton {
          required property var modelData
          text: modelData.text
          accent: modelData.identifier === "default"
          onClicked: card.action(modelData.identifier)
        }
      }
    }
  }

  Rectangle {
    visible: card.duration > 0
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 1
    x: background.radius
    height: 1.5
    radius: 0.75
    width: (parent.width - background.radius * 2) * card.remaining
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: Qt.alpha(card.accent, 0.15) }
      GradientStop { position: 1.0; color: Qt.alpha(card.accent, 0.8) }
    }
  }

  HoverHandler {
    id: hover
    cursorShape: Qt.PointingHandCursor
  }

  TapHandler {
    acceptedButtons: Qt.LeftButton
    onTapped: card.clicked()
  }
  TapHandler {
    acceptedButtons: Qt.RightButton
    onTapped: card.leave("dismissed")
  }
}
