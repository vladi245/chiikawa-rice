import QtQuick

Item {
  id: toggle

  property bool checked: false
  signal toggled(bool checked)

  implicitWidth: Theme.size(38)
  implicitHeight: Theme.size(20)
  opacity: enabled ? 1 : 0.45

  onCheckedChanged: if (Theme.fx)
                      hop.restart()

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: toggle.checked ? Theme.blush : Theme.tan
    border.width: 1.5
    border.color: Theme.line
    Behavior on color {
      ColorAnimation { duration: 220 }
    }
  }

  Rectangle {
    id: knob
    width: toggle.height - 6
    height: width
    radius: width / 2
    anchors.verticalCenter: parent.verticalCenter
    x: toggle.checked ? toggle.width - width - 3 : 3
    color: Theme.white
    border.width: 1.5
    border.color: Theme.line
    Behavior on x {
      enabled: Theme.fx
      SpringAnimation { spring: 5; damping: 0.3; epsilon: 0.2 }
    }

    Repeater {
      model: 2
      delegate: Rectangle {
        required property int index
        visible: toggle.checked
        width: knob.width * 0.22
        height: width * 0.6
        radius: height / 2
        color: Theme.pink
        opacity: 0.8
        x: index === 0 ? knob.width * 0.16 : knob.width * 0.62
        y: knob.height * 0.55
      }
    }

    transform: Scale {
      id: squash
      origin.x: knob.width / 2
      origin.y: knob.height
    }
  }

  SequentialAnimation {
    id: hop
    ParallelAnimation {
      NumberAnimation { target: squash; property: "xScale"; to: 1.25; duration: 80 }
      NumberAnimation { target: squash; property: "yScale"; to: 0.8; duration: 80 }
    }
    ParallelAnimation {
      SpringAnimation { target: squash; property: "xScale"; to: 1; spring: 6; damping: 0.25; epsilon: 0.005 }
      SpringAnimation { target: squash; property: "yScale"; to: 1; spring: 6; damping: 0.25; epsilon: 0.005 }
    }
  }

  MouseArea {
    anchors.fill: parent
    anchors.margins: -4
    enabled: toggle.enabled
    cursorShape: Qt.PointingHandCursor
    onClicked: toggle.toggled(!toggle.checked)
  }
}
