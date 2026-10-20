import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: bar

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property string icon: ""
  property bool lit: false
  property bool dim: false
  property string label: ""
  property bool showLabel: false
  property string tooltip: ""
  property bool shown: true
  property real glyphScale: 1
  property alias glyph: glyph
  default property alias extras: overlay.data

  signal clicked
  signal rightClicked
  signal middleClicked
  signal wheel(int delta)

  readonly property string screenName: screen?.name ?? ""
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real fontSize: Style.getBarFontSizeForScreen(screenName)
  readonly property bool hot: area.containsMouse
  readonly property bool labelOpen: label !== "" && (showLabel || hot)
  readonly property bool panelOpen: pluginApi?.panelOpenScreen !== null && pluginApi?.panelOpenScreen !== undefined

  visible: shown
  implicitWidth: shown ? Math.round(capsuleHeight + labelBox.width) : 0
  implicitHeight: capsuleHeight

  function togglePanel() {
    pluginApi?.togglePanel(screen, bar);
  }

  Item {
    id: iconBox
    width: bar.capsuleHeight
    height: bar.capsuleHeight
    anchors.verticalCenter: parent.verticalCenter

    Rectangle {
      id: sticker
      anchors.centerIn: parent
      width: bar.capsuleHeight * 0.92
      height: width
      radius: width / 2
      color: Theme.blush
      border.width: 1.5
      border.color: Theme.line
      scale: bar.hot || bar.panelOpen ? 1 : 0
      Behavior on scale {
        enabled: Theme.fx
        NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
      }
    }

    NIcon {
      id: glyph
      anchors.centerIn: parent
      icon: bar.icon || "point"
      scale: bar.glyphScale * squash.level
      pointSize: bar.fontSize * 1.1
      applyUiScale: false
      color: bar.dim ? Theme.inkFaint : (bar.hot || bar.panelOpen ? Theme.line : (bar.lit ? Theme.pink : Theme.inkSoft))
      Behavior on color {
        ColorAnimation { duration: 200 }
      }
    }

    QtObject {
      id: squash
      property real level: 1
    }
    SequentialAnimation {
      id: boing
      NumberAnimation { target: squash; property: "level"; to: 0.78; duration: 70 }
      SpringAnimation { target: squash; property: "level"; to: 1; spring: 7; damping: 0.22; epsilon: 0.005 }
    }

    Item {
      id: overlay
      anchors.fill: parent
    }
  }

  Item {
    id: labelBox
    anchors.left: iconBox.right
    anchors.verticalCenter: parent.verticalCenter
    height: parent.height
    width: bar.labelOpen ? labelText.implicitWidth + Style.marginS : 0
    clip: true
    Behavior on width {
      NumberAnimation { duration: 240; easing.type: Easing.OutBack }
    }

    Text {
      id: labelText
      anchors.verticalCenter: parent.verticalCenter
      text: bar.label
      font.family: Theme.font
      font.pointSize: bar.fontSize * 0.9
      font.weight: Font.Bold
      color: Theme.ink
      opacity: bar.labelOpen ? 1 : 0
      Behavior on opacity {
        NumberAnimation { duration: 220 }
      }
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onEntered: {
      if (bar.tooltip !== "" && !bar.panelOpen)
        TooltipService.show(bar, bar.tooltip, BarService.getTooltipDirection(bar.screenName));
    }
    onExited: TooltipService.hide()
    onClicked: mouse => {
                 TooltipService.hide();
                 if (Theme.fx)
                   boing.restart();
                 if (mouse.button === Qt.RightButton)
                   bar.rightClicked();
                 else if (mouse.button === Qt.MiddleButton)
                   bar.middleClicked();
                 else
                   bar.clicked();
               }
    onWheel: wheel => bar.wheel(wheel.angleDelta.y)
  }
}
