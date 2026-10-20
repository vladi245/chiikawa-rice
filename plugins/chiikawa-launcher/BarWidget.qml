import QtQuick
import Quickshell
import qs.Commons
import qs.Services.System
import "../../chiikawa"

Item {
  id: root
  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property string screenName: screen?.name ?? ""
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property bool open: pluginApi?.panelOpenScreen !== null && pluginApi?.panelOpenScreen !== undefined
  readonly property bool active: hover.hovered || open
  readonly property int logoSize: Style.toOdd(capsuleHeight * 0.66)

  implicitWidth: capsuleHeight + Style.marginXS
  implicitHeight: capsuleHeight

  Rectangle {
    anchors.centerIn: parent
    width: root.capsuleHeight * 0.92
    height: width
    radius: width / 2
    color: Woodland.blush
    border.width: 1.5
    border.color: Woodland.line
    scale: root.active ? 1 : 0
    Behavior on scale {
      enabled: Woodland.fx
      NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
    }
  }

  Image {
    id: logo
    anchors.centerIn: parent
    width: root.logoSize
    height: width
    sourceSize: Qt.size(width * 2, height * 2)
    source: HostService.osLogo
    smooth: true
    scale: squash.level * (root.active ? 0.84 : 1)
    Behavior on scale {
      NumberAnimation { duration: 220; easing.type: Easing.OutBack }
    }
  }

  QtObject {
    id: squash
    property real level: 1
  }
  SequentialAnimation {
    id: boing
    NumberAnimation { target: squash; property: "level"; to: 0.75; duration: 70 }
    SpringAnimation { target: squash; property: "level"; to: 1; spring: 7; damping: 0.22; epsilon: 0.005 }
  }

  Item {
    id: orbit
    anchors.centerIn: parent
    width: root.capsuleHeight * 1.05
    height: width
    opacity: root.active && Woodland.fx ? 1 : 0
    visible: opacity > 0
    Behavior on opacity {
      NumberAnimation { duration: 200 }
    }

    RotationAnimation on rotation {
      running: orbit.visible
      from: 0
      to: 360
      duration: root.open ? 2200 : 3600
      loops: Animation.Infinite
    }

    Repeater {
      model: 3
      delegate: Text {
        required property int index
        readonly property real angle: index * Math.PI * 2 / 3
        text: index === 0 ? "♥" : "✦"
        color: index === 1 ? Woodland.ember : Woodland.windowLight
        font.pixelSize: root.capsuleHeight * 0.24
        x: orbit.width / 2 + Math.cos(angle) * orbit.width / 2 - width / 2
        y: orbit.height / 2 + Math.sin(angle) * orbit.height / 2 - height / 2
        rotation: -orbit.rotation
      }
    }
  }

  HoverHandler {
    id: hover
    cursorShape: Qt.PointingHandCursor
  }

  TapHandler {
    onTapped: {
      if (Woodland.fx)
        boing.restart();
      root.pluginApi?.togglePanel(root.screen, root);
    }
  }
}
