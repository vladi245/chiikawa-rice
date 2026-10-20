import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI
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
  readonly property bool hot: hover.hovered || open

  CastFile {
    id: castFile
  }
  readonly property string who: castFile.who("pet") === "none" ? "hachiware" : castFile.who("pet")

  implicitWidth: capsuleHeight + Style.marginXS
  implicitHeight: capsuleHeight

  Rectangle {
    anchors.centerIn: parent
    width: root.capsuleHeight * 0.92
    height: width
    radius: width / 2
    color: Theme.blush
    border.width: 1.5
    border.color: Theme.line
    scale: root.hot ? 1 : 0
    Behavior on scale {
      enabled: Theme.fx
      NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
    }
  }

  Friend {
    id: face
    anchors.centerIn: parent
    width: root.capsuleHeight * 0.86
    kind: root.who
    role: root.hot ? "idle" : ""
    animated: Theme.fx
  }

  HoverHandler {
    id: hover
    cursorShape: Qt.PointingHandCursor
    onHoveredChanged: {
      if (hovered)
        TooltipService.show(root, "Cast: who appears where", BarService.getTooltipDirection(root.screenName));
      else
        TooltipService.hide();
    }
  }
  TapHandler {
    onTapped: {
      TooltipService.hide();
      face.boing();
      root.pluginApi?.togglePanel(root.screen, root);
    }
  }
}
