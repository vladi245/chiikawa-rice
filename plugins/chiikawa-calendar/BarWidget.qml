import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root
  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property string screenName: screen?.name ?? ""
  readonly property string format: "HH:mm  ·  ddd dd MMM"

  implicitWidth: Math.round(label.implicitWidth + Style.margin2M)
  implicitHeight: Style.getCapsuleHeightForScreen(screenName)

  NText {
    id: label
    anchors.centerIn: parent
    text: I18n.locale.toString(Time.now, root.format)
    pointSize: Style.getBarFontSizeForScreen(root.screenName)
    applyUiScale: false
    color: Color.mOnSurface
    features: ({ "tnum": 1 })
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: {
      if (!root.pluginApi?.panelOpenScreen)
        TooltipService.show(root, I18n.locale.toString(Time.now, "dddd, d MMMM yyyy"), BarService.getTooltipDirection(root.screenName));
    }
    onExited: TooltipService.hide()
    onClicked: {
      TooltipService.hide();
      root.pluginApi?.togglePanel(root.screen, root);
    }
  }
}
