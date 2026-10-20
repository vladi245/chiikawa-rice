import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Services.Compositor
import qs.Services.Power

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

  readonly property int dot: Style.toOdd(capsuleHeight * 0.36)
  readonly property int pillWidth: Math.round(dot * 2.6)
  readonly property int pillHeight: Style.toOdd(capsuleHeight * 0.62)
  readonly property int gap: Math.round(dot * 0.85)
  readonly property int pad: Style.marginS

  property ListModel spaces: ListModel {}
  property int focusedIndex: -1
  property int travel: 1 // +1 moving right, -1 moving left
  property int wheelAccumulated: 0

  implicitWidth: pad * 2 + Math.max(0, spaces.count - 1) * (dot + gap) + (spaces.count > 0 ? pillWidth : 0)
  implicitHeight: capsuleHeight

  function slotX(i) {
    let x = pad;
    for (let j = 0; j < i; j++)
      x += (j === focusedIndex ? pillWidth : dot) + gap;
    return x;
  }

  function refresh() {
    const name = screenName.toLowerCase();
    const next = [];
    for (let i = 0; i < CompositorService.workspaces.count; i++) {
      const ws = CompositorService.workspaces.get(i);
      if (!CompositorService.globalWorkspaces && ws.output.toLowerCase() !== name)
        continue;
      next.push({
                  "id": ws.id,
                  "idx": ws.idx,
                  "name": ws.name,
                  "isFocused": ws.isFocused,
                  "isOccupied": ws.isOccupied,
                  "isUrgent": ws.isUrgent
                });
    }
    // Update in place so delegates (and their animations) survive.
    let i = 0;
    while (i < spaces.count || i < next.length) {
      if (i < spaces.count && i < next.length) {
        if (spaces.get(i).id === next[i].id) {
          spaces.set(i, next[i]);
          i++;
        } else {
          spaces.remove(i);
        }
      } else if (i < spaces.count) {
        spaces.remove(i);
      } else {
        spaces.append(next[i]);
        i++;
      }
    }
    const focused = next.findIndex(ws => ws.isFocused);
    if (focused !== focusedIndex) {
      if (focusedIndex >= 0 && focused >= 0) {
        travel = focused > focusedIndex ? 1 : -1;
        if (fx)
          arrival.restart();
      }
      focusedIndex = focused;
    }
  }

  function switchBy(offset) {
    if (spaces.count < 2)
      return;
    const from = Math.max(0, focusedIndex);
    const to = (from + offset + spaces.count) % spaces.count;
    CompositorService.switchToWorkspace(spaces.get(to));
  }

  Component.onCompleted: Qt.callLater(refresh)
  onScreenNameChanged: Qt.callLater(refresh)

  Connections {
    target: CompositorService
    function onWorkspacesChanged() {
      Qt.callLater(root.refresh);
    }
  }

  Item {
    id: blob
    readonly property real targetLeft: root.focusedIndex >= 0 ? root.slotX(root.focusedIndex) : root.pad
    readonly property real targetRight: targetLeft + root.pillWidth
    property real edgeL: targetLeft
    property real edgeR: targetRight
    readonly property real stretch: Math.max(0, (edgeR - edgeL) - root.pillWidth)

    visible: root.focusedIndex >= 0
    x: edgeL
    width: edgeR - edgeL
    height: root.pillHeight - Math.min(root.pillHeight * 0.35, stretch * 0.12)
    anchors.verticalCenter: parent.verticalCenter

    Behavior on edgeL {
      enabled: root.fx
      SpringAnimation {
        spring: root.travel < 0 ? 7 : 1.8
        damping: root.travel < 0 ? 0.5 : 0.26
        epsilon: 0.2
      }
    }
    Behavior on edgeR {
      enabled: root.fx
      SpringAnimation {
        spring: root.travel > 0 ? 7 : 1.8
        damping: root.travel > 0 ? 0.5 : 0.26
        epsilon: 0.2
      }
    }

    Rectangle {
      id: pill
      anchors.fill: parent
      radius: height / 2
      color: Color.mPrimary
      layer.enabled: root.fx
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Color.mPrimary
        shadowBlur: glow.level
        shadowOpacity: 0.55 + glow.level * 0.4
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
        blurMax: 16
      }
    }

    Text {
      anchors.centerIn: parent
      text: root.focusedIndex >= 0 && root.focusedIndex < root.spaces.count ? root.spaces.get(root.focusedIndex).idx : ""
      font.family: Settings.data.ui.fontDefault
      font.pointSize: root.fontSize * 0.78
      font.weight: Font.Bold
      color: Color.mOnPrimary
      opacity: Math.max(0, 1 - blob.stretch / (root.dot * 1.5))
    }
  }

  QtObject {
    id: glow
    property real level: 0.45
  }

  SequentialAnimation {
    id: arrival
    NumberAnimation { target: glow; property: "level"; to: 1.0; duration: Style.animationFast; easing.type: Easing.OutQuad }
    NumberAnimation { target: glow; property: "level"; to: 0.45; duration: Style.animationSlowest; easing.type: Easing.InOutSine }
  }

  Row {
    id: slots
    x: root.pad
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.gap

    Repeater {
      model: root.spaces

      delegate: Item {
        id: slot
        required property int index
        required property var model
        readonly property bool focused: index === root.focusedIndex

        width: focused ? root.pillWidth : root.dot
        height: root.pillHeight
        Behavior on width {
          enabled: root.fx
          NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic }
        }

        Rectangle {
          id: bead
          anchors.centerIn: parent
          width: root.dot * (hover.hovered ? 1.25 : 1) * (slot.model.isOccupied ? 0.82 : 0.7)
          height: width
          radius: width / 2
          visible: !slot.focused
          color: slot.model.isUrgent ? Color.mError : (slot.model.isOccupied ? Color.mOnSurfaceVariant : "transparent")
          border.width: slot.model.isOccupied || slot.model.isUrgent ? 0 : Math.max(1, Style.borderS * 1.2)
          border.color: Qt.alpha(Color.mOnSurfaceVariant, 0.7)
          Behavior on width {
            enabled: root.fx
            NumberAnimation { duration: Style.animationFast; easing.type: Easing.OutBack }
          }
        }

        Rectangle {
          anchors.centerIn: parent
          width: root.dot
          height: width
          radius: width / 2
          color: "transparent"
          border.width: 1
          border.color: Color.mError
          visible: slot.model.isUrgent && root.fx
          SequentialAnimation on scale {
            running: slot.model.isUrgent && root.fx
            loops: Animation.Infinite
            NumberAnimation { from: 0.8; to: 2.4; duration: 1100; easing.type: Easing.OutCubic }
            PauseAnimation { duration: 300 }
          }
          SequentialAnimation on opacity {
            running: slot.model.isUrgent && root.fx
            loops: Animation.Infinite
            NumberAnimation { from: 0.9; to: 0; duration: 1100; easing.type: Easing.OutCubic }
            PauseAnimation { duration: 300 }
          }
        }

        Rectangle {
          id: ripple
          anchors.centerIn: parent
          width: root.pillHeight
          height: width
          radius: width / 2
          color: "transparent"
          border.width: 1.5
          border.color: Color.mPrimary
          opacity: 0
        }

        ParallelAnimation {
          id: rippleAnim
          NumberAnimation { target: ripple; property: "scale"; from: 0.4; to: 2.2; duration: Style.animationSlowest; easing.type: Easing.OutCubic }
          NumberAnimation { target: ripple; property: "opacity"; from: 0.9; to: 0; duration: Style.animationSlowest; easing.type: Easing.OutQuad }
        }

        HoverHandler {
          id: hover
          cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
          onTapped: {
            if (root.fx)
              rippleAnim.restart();
            CompositorService.switchToWorkspace(slot.model);
          }
        }
      }
    }
  }

  WheelHandler {
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: event => {
               root.wheelAccumulated += Math.abs(event.angleDelta.y) >= Math.abs(event.angleDelta.x) ? event.angleDelta.y : event.angleDelta.x;
               if (Math.abs(root.wheelAccumulated) < 120)
                 return;
               let direction = root.wheelAccumulated > 0 ? -1 : 1;
               if (Settings.data.general.reverseScroll)
                 direction *= -1;
               root.wheelAccumulated = 0;
               root.switchBy(direction);
             }
  }
}
