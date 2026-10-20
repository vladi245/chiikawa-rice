import QtQuick

// Used only if ChiikawaLockView.qml fails to load, so it stays dependency-free.
Item {
  id: view
  required property var controller

  Rectangle {
    anchors.fill: parent
    color: "#fcf6e7"
  }

  Column {
    anchors.centerIn: parent
    spacing: 20

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatTime(view.controller.now, "HH:mm")
      color: "#4b302b"
      font.family: "Nunito"
      font.pixelSize: 96
      font.weight: Font.Black
    }

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      width: 320
      height: 52
      radius: 26
      color: "#fffdf8"
      border.width: 2
      border.color: view.controller.error ? "#d65a5a" : "#e3708b"

      TextInput {
        id: field
        anchors.fill: parent
        anchors.margins: 14
        echoMode: TextInput.Password
        enabled: !view.controller.busy && !view.controller.unlocking
        color: "#4b302b"
        font.pixelSize: 20
        horizontalAlignment: TextInput.AlignHCenter
        verticalAlignment: TextInput.AlignVCenter
        onAccepted: {
          view.controller.submit(text);
          text = "";
        }
        Component.onCompleted: Qt.callLater(forceActiveFocus)
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: view.controller.status || "password, please"
      color: view.controller.error ? "#d65a5a" : "#9c8273"
      font.family: "Nunito"
      font.pixelSize: 16
    }
  }

  Connections {
    target: view.controller
    function onBusyChanged() {
      if (!view.controller.busy)
        Qt.callLater(field.forceActiveFocus);
    }
  }
}
