import QtQuick

Rectangle {
  id: field

  property alias text: input.text
  property string placeholder: "passphrase"
  property bool secret: true
  property bool active: true
  property bool focusOnShow: false
  property bool _reveal: false
  signal accepted
  signal cancelled

  height: Woodland.size(30)
  radius: height / 2
  color: Woodland.white
  border.width: input.activeFocus ? 2 : 1.5
  border.color: input.activeFocus ? Woodland.windowLight : Woodland.line

  onActiveChanged: if (active && focusOnShow)
                     input.forceActiveFocus()
  Component.onCompleted: if (active && focusOnShow)
                           input.forceActiveFocus()

  TextInput {
    id: input
    anchors.left: parent.left
    anchors.leftMargin: Woodland.size(12)
    anchors.right: eye.visible ? eye.left : parent.right
    anchors.rightMargin: Woodland.size(6)
    anchors.verticalCenter: parent.verticalCenter
    echoMode: field.secret && !field._reveal ? TextInput.Password : TextInput.Normal
    passwordCharacter: "♥"
    font.family: Woodland.font
    font.pointSize: 9
    color: Woodland.mist
    selectionColor: Woodland.blush
    selectedTextColor: Woodland.line
    clip: true
    onAccepted: field.accepted()
    Keys.onEscapePressed: field.cancelled()

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: !input.text
      text: field.placeholder
      font: input.font
      color: Woodland.bark
    }
  }

  WButton {
    id: eye
    visible: field.secret
    anchors.right: parent.right
    anchors.rightMargin: Woodland.size(3)
    anchors.verticalCenter: parent.verticalCenter
    implicitHeight: Woodland.size(24)
    icon: field._reveal ? "eye-off" : "eye"
    onClicked: field._reveal = !field._reveal
  }
}
