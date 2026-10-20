import QtQuick
import QtQuick.Effects
import qs.Services.System
import "../../woodland"

BarGlyph {
  id: root

  readonly property bool dnd: NotificationService.doNotDisturb
  readonly property int total: NotificationService.historyModel.count
  readonly property int unread: {
    const since = NotificationService.lastSeenTs;
    const model = NotificationService.historyModel;
    let n = 0;
    for (let i = 0; i < model.count; i++) {
      const ts = model.get(i).timestamp;
      if ((ts instanceof Date ? ts.getTime() : ts) > since)
        n++;
    }
    return n;
  }

  icon: dnd ? "bell-off" : (unread > 0 ? "bell-ringing" : "bell")
  dim: dnd
  lit: unread > 0
  label: unread > 0 ? String(unread) : ""
  tooltip: dnd ? "Do not disturb" : (unread > 0 ? unread + " unread" : "No new notifications")

  onClicked: togglePanel()
  onMiddleClicked: NotificationService.doNotDisturb = !dnd
  onRightClicked: NotificationService.doNotDisturb = !dnd

  glyph.transformOrigin: Item.Top

  property int _lastTotal: -1
  onTotalChanged: {
    if (_lastTotal >= 0 && total > _lastTotal && Woodland.fx && !dnd)
      swing.restart();
    _lastTotal = total;
  }
  Component.onCompleted: _lastTotal = total

  SequentialAnimation {
    id: swing
    NumberAnimation { target: root.glyph; property: "rotation"; to: 22; duration: 110; easing.type: Easing.OutQuad }
    NumberAnimation { target: root.glyph; property: "rotation"; to: -17; duration: 200; easing.type: Easing.InOutSine }
    NumberAnimation { target: root.glyph; property: "rotation"; to: 11; duration: 190; easing.type: Easing.InOutSine }
    NumberAnimation { target: root.glyph; property: "rotation"; to: -6; duration: 180; easing.type: Easing.InOutSine }
    NumberAnimation { target: root.glyph; property: "rotation"; to: 2; duration: 160; easing.type: Easing.InOutSine }
    NumberAnimation { target: root.glyph; property: "rotation"; to: 0; duration: 150; easing.type: Easing.OutQuad }
  }

  Rectangle {
    id: ember
    visible: root.unread > 0 && !root.dnd
    width: Math.max(3, root.capsuleHeight * 0.17)
    height: width
    radius: width / 2
    x: parent.width * 0.68
    y: parent.height * 0.16
    color: Woodland.ember
    opacity: Woodland.fx ? 0.65 + glowLevel.value * 0.35 : 1
    layer.enabled: Woodland.fx
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Woodland.ember
      shadowBlur: 0.8
      shadowOpacity: 0.5 + glowLevel.value * 0.5
      shadowHorizontalOffset: 0
      shadowVerticalOffset: 0
      blurMax: 12
    }
  }

  QtObject {
    id: glowLevel
    property real value: 1
  }
  SequentialAnimation {
    running: ember.visible && Woodland.fx
    loops: Animation.Infinite
    NumberAnimation { target: glowLevel; property: "value"; to: 0.2; duration: 1300; easing.type: Easing.InOutSine }
    NumberAnimation { target: glowLevel; property: "value"; to: 1; duration: 1300; easing.type: Easing.InOutSine }
  }
}
