import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.Commons
import qs.Services.Hardware
import qs.Services.Power
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

  readonly property var device: BatteryService.primaryDevice
  readonly property bool ready: BatteryService.batteryReady && BatteryService.batteryPercentage >= 0
  readonly property real percent: Math.max(0, Math.min(100, BatteryService.batteryPercentage))
  readonly property bool charging: BatteryService.batteryCharging
  readonly property bool low: BatteryService.isLowBattery(device) || BatteryService.isCriticalBattery(device)
  readonly property bool critical: BatteryService.isCriticalBattery(device)
  readonly property color liquidColor: low ? Color.mError : Color.mPrimary

  readonly property int cellWidth: Math.round(capsuleHeight * 1.1)
  readonly property int cellHeight: Style.toOdd(capsuleHeight * 0.58)

  visible: ready
  implicitWidth: ready ? Math.round(cell.width + nub.width + Style.marginXS + readout.implicitWidth + Style.margin2S) : 0
  implicitHeight: capsuleHeight

  component Wave: Shape {
    id: wave
    property real wavelength: tank.width * 0.9
    property real amplitude: 1.4
    property color fill: root.liquidColor
    property int durationMs: 2200
    property bool flowing: root.fx
    property bool reversed: false

    width: wavelength * 2
    height: tank.height + amplitude * 2
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeWidth: 0
      strokeColor: "transparent"
      fillColor: wave.fill
      PathSvg {
        path: {
          const w = wave.wavelength, a = wave.amplitude, steps = 24;
          let d = `M 0 ${a}`;
          for (let i = 1; i <= steps * 2; i++) {
            const x = i * w / steps;
            d += ` L ${x.toFixed(2)} ${(a - Math.sin(x / w * Math.PI * 2) * a).toFixed(2)}`;
          }
          return d + ` L ${2 * w} ${wave.height} L 0 ${wave.height} Z`;
        }
      }
    }

    NumberAnimation on x {
      running: wave.flowing
      from: wave.reversed ? -wave.wavelength : 0
      to: wave.reversed ? 0 : -wave.wavelength
      duration: wave.durationMs
      loops: Animation.Infinite
    }
  }

  Item {
    id: body
    anchors.verticalCenter: parent.verticalCenter
    x: Style.marginS
    width: cell.width + nub.width
    height: cell.height

    Rectangle {
      id: cell
      width: root.cellWidth
      height: root.cellHeight
      radius: Math.round(height * 0.3)
      color: Qt.alpha(Color.mSurfaceVariant, 0.6)
      border.width: Math.max(1, Style.borderS)
      border.color: root.low ? Qt.alpha(Color.mError, root.fx ? 0.45 + alarm.level * 0.55 : 1) : Qt.alpha(Color.mOnSurfaceVariant, 0.75)

      Item {
        id: tank
        anchors.fill: parent
        anchors.margins: cell.border.width + 1
        visible: false
        layer.enabled: true

        property real level: root.percent / 100
        Behavior on level {
          NumberAnimation { duration: Style.animationSlowest; easing.type: Easing.OutCubic }
        }
        readonly property real surface: height * (1 - level)

        Wave {
          y: tank.surface - amplitude * 2
          fill: Qt.alpha(root.liquidColor, 0.4)
          wavelength: tank.width * 0.7
          durationMs: root.charging ? 1100 : 2900
        }
        Wave {
          y: tank.surface - amplitude
          fill: Qt.alpha(root.liquidColor, 0.9)
          durationMs: root.charging ? 1500 : 3600
          reversed: true
        }

        Repeater {
          model: 4
          delegate: Rectangle {
            id: bubble
            required property int index
            readonly property real startX: tank.width * (0.18 + index * 0.21)
            width: 1.6 + (index % 2) * 0.9
            height: width
            radius: width / 2
            x: startX
            y: tank.height
            color: Color.mOnPrimary
            opacity: 0
            visible: root.charging && root.fx

            SequentialAnimation {
              running: bubble.visible
              loops: Animation.Infinite
              PauseAnimation { duration: bubble.index * 380 }
              ParallelAnimation {
                NumberAnimation { target: bubble; property: "y"; from: tank.height; to: tank.surface; duration: 1300 + bubble.index * 120; easing.type: Easing.InQuad }
                NumberAnimation { target: bubble; property: "x"; from: bubble.startX; to: bubble.startX + (bubble.index % 2 ? 1.5 : -1.5); duration: 1300; easing.type: Easing.InOutSine }
                SequentialAnimation {
                  NumberAnimation { target: bubble; property: "opacity"; from: 0; to: 0.85; duration: 300 }
                  PauseAnimation { duration: 700 }
                  NumberAnimation { target: bubble; property: "opacity"; to: 0; duration: 300 }
                }
              }
              PauseAnimation { duration: (3 - bubble.index) * 380 }
            }
          }
        }
      }

      Rectangle {
        id: tankMask
        anchors.fill: tank
        radius: Math.max(0, cell.radius - cell.border.width - 1)
        visible: false
        layer.enabled: true
      }

      MultiEffect {
        anchors.fill: tank
        source: tank
        maskEnabled: true
        maskSource: tankMask
      }

      NIcon {
        anchors.centerIn: parent
        visible: root.charging
        icon: "bolt"
        pointSize: root.fontSize * 0.95
        applyUiScale: false
        color: root.percent > 55 ? Color.mOnPrimary : Color.mPrimary
        scale: root.fx ? 0.9 + alarm.level * 0.2 : 1
        layer.enabled: root.fx
        layer.effect: MultiEffect {
          shadowEnabled: true
          shadowColor: Color.mPrimary
          shadowBlur: 0.5
          shadowOpacity: 0.3 + alarm.level * 0.5
          shadowHorizontalOffset: 0
          shadowVerticalOffset: 0
          blurMax: 10
        }
      }
    }

    Rectangle {
      id: nub
      anchors.left: cell.right
      anchors.leftMargin: 1
      anchors.verticalCenter: cell.verticalCenter
      width: 2
      height: Math.round(cell.height * 0.42)
      radius: 1
      color: cell.border.color
    }

    layer.enabled: root.fx && root.critical
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Color.mError
      shadowBlur: 0.4 + alarm.level * 0.6
      shadowOpacity: alarm.level
      shadowHorizontalOffset: 0
      shadowVerticalOffset: 0
      blurMax: 14
    }
  }

  Text {
    id: readout
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: body.right
    anchors.leftMargin: Style.marginXS
    text: Math.round(root.percent) + "%"
    font.family: Settings.data.ui.fontDefault
    font.pointSize: root.fontSize * 0.92
    font.weight: Font.Medium
    color: root.low ? Color.mError : Color.mOnSurface
  }

  QtObject {
    id: alarm
    property real level: 1
  }

  SequentialAnimation {
    running: root.fx && (root.low || root.charging)
    loops: Animation.Infinite
    onRunningChanged: if (!running)
                        alarm.level = 1
    NumberAnimation { target: alarm; property: "level"; to: 0.2; duration: root.critical ? 450 : 1100; easing.type: Easing.InOutSine }
    NumberAnimation { target: alarm; property: "level"; to: 1; duration: root.critical ? 450 : 1100; easing.type: Easing.InOutSine }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: {
      if (!PanelService.getPanel("batteryPanel", root.screen)?.isPanelOpen)
        TooltipService.show(root, `${Math.round(root.percent)}% · ${BatteryService.getTimeRemainingText(root.device)}`, BarService.getTooltipDirection(root.screenName));
    }
    onExited: TooltipService.hide()
    onClicked: {
      TooltipService.hide();
      PanelService.getPanel("batteryPanel", root.screen)?.toggle(root);
    }
  }
}
