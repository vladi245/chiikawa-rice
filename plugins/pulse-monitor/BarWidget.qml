import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Services.Power
import qs.Services.System
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
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real fontSize: Style.getBarFontSizeForScreen(screenName)
  readonly property bool fx: !Settings.data.general.animationDisabled && !PowerProfileService.noctaliaPerformanceMode
  readonly property string registrationId: "plugin:pulse-monitor:" + (screenName || "unknown")

  implicitWidth: Math.round(row.implicitWidth + Style.margin2S)
  implicitHeight: capsuleHeight

  Component.onCompleted: SystemStatService.registerComponent(registrationId)
  Component.onDestruction: SystemStatService.unregisterComponent(registrationId)

  component Stat: Item {
    id: stat

    property string icon: ""
    property string value: ""
    property real ratio: 0 // meter fill, 0..1
    property bool warning: false
    property bool critical: false
    property alias glyph: glyph

    readonly property color tone: critical ? Color.mError : (warning ? Color.mTertiary : Color.mOnSurface)

    implicitWidth: glyph.width + Style.marginXS + Math.max(valueText.implicitWidth, valueMetrics.width)
    implicitHeight: root.capsuleHeight

    NIcon {
      id: glyph
      anchors.verticalCenter: parent.verticalCenter
      icon: stat.icon
      pointSize: root.fontSize * 1.05
      applyUiScale: false
      color: stat.critical ? Color.mError : Color.mOnSurfaceVariant
    }

    // Reserve room for the widest value ("100%") so neighbours don't shift.
    TextMetrics {
      id: valueMetrics
      font: valueText.font
      text: "100%"
    }

    Text {
      id: valueText
      x: glyph.width + Style.marginXS
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: -1
      text: stat.value
      font.family: Settings.data.ui.fontFixed
      font.pointSize: root.fontSize * 0.88
      font.weight: Font.Medium
      color: stat.tone
      Behavior on color {
        ColorAnimation { duration: Style.animationSlow }
      }
      layer.enabled: root.fx && stat.critical
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Color.mError
        shadowBlur: 0.4 + breath.level * 0.5
        shadowOpacity: breath.level
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
        blurMax: 14
      }
    }

    Rectangle {
      id: track
      x: valueText.x
      width: valueMetrics.width
      height: 1.5
      radius: 0.75
      anchors.top: valueText.bottom
      anchors.topMargin: 1
      color: Qt.alpha(Color.mOutline, 0.7)

      Rectangle {
        height: parent.height
        radius: parent.radius
        width: Math.max(height, parent.width * Math.max(0, Math.min(1, stat.ratio)))
        color: stat.tone
        opacity: 0.85
        Behavior on width {
          enabled: root.fx
          NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic }
        }
      }
    }
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.marginM

    Stat {
      icon: "cpu-usage"
      value: Math.round(SystemStatService.cpuUsage) + "%"
      ratio: SystemStatService.cpuUsage / 100
      warning: SystemStatService.cpuWarning
      critical: SystemStatService.cpuCritical
    }

    Stat {
      icon: "memory"
      value: Math.round(SystemStatService.memPercent) + "%"
      ratio: SystemStatService.memPercent / 100
      warning: SystemStatService.memWarning
      critical: SystemStatService.memCritical
    }

    Stat {
      id: temp
      icon: "cpu-temperature"
      value: Math.round(SystemStatService.cpuTemp) + "°"
      ratio: SystemStatService.cpuTemp / Math.max(1, SystemStatService.tempCriticalThreshold)
      warning: SystemStatService.tempWarning
      critical: SystemStatService.tempCritical
      glyph.opacity: root.fx && SystemStatService.tempWarning ? 0.55 + flicker.level * 0.45 : 1
    }
  }

  QtObject {
    id: breath
    property real level: 1
  }
  SequentialAnimation {
    running: root.fx && (SystemStatService.cpuCritical || SystemStatService.memCritical || SystemStatService.tempCritical)
    loops: Animation.Infinite
    NumberAnimation { target: breath; property: "level"; to: 0.35; duration: 900; easing.type: Easing.InOutSine }
    NumberAnimation { target: breath; property: "level"; to: 1; duration: 900; easing.type: Easing.InOutSine }
  }

  QtObject {
    id: flicker
    property real level: 1
  }
  Timer {
    running: root.fx && SystemStatService.tempWarning
    repeat: true
    interval: 120
    onTriggered: flicker.level = Math.random()
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: {
      if (!PanelService.getPanel("systemStatsPanel", root.screen)?.isPanelOpen)
        TooltipService.show(root, `CPU ${Math.round(SystemStatService.cpuUsage)}% · ${SystemStatService.cpuFreq}\nRAM ${SystemStatService.memGb.toFixed(1)} / ${SystemStatService.memTotalGb.toFixed(1)} GB\nTemp ${Math.round(SystemStatService.cpuTemp)}°C`, BarService.getTooltipDirection(root.screenName));
    }
    onExited: TooltipService.hide()
    onClicked: {
      TooltipService.hide();
      PanelService.getPanel("systemStatsPanel", root.screen)?.toggle(root);
    }
  }
}
