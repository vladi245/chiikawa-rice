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

  height: Theme.size(30)
  radius: height / 2
  color: Theme.white
  border.width: input.activeFocus ? 2 : 1.5
  border.color: input.activeFocus ? Theme.pink : Theme.line

  onActiveChanged: if (active && focusOnShow)
                     input.forceActiveFocus()
  Component.onCompleted: if (active && focusOnShow)
                           input.forceActiveFocus()

  TextInput {
    id: input
    anchors.left: parent.left
    anchors.leftMargin: Theme.size(12)
    anchors.right: eye.visible ? eye.left : parent.right
    anchors.rightMargin: Theme.size(6)
    anchors.verticalCenter: parent.verticalCenter
    echoMode: field.secret && !field._reveal ? TextInput.Password : TextInput.Normal
    passwordCharacter: "♥"
    font.family: Theme.font
    font.pointSize: 9
    color: Theme.ink
    selectionColor: Theme.blush
    selectedTextColor: Theme.line
    clip: true
    onAccepted: field.accepted()
    Keys.onEscapePressed: field.cancelled()

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: !input.text
      text: field.placeholder
      font: input.font
      color: Theme.inkFaint
    }
  }

  CButton {
    id: eye
    visible: field.secret
    anchors.right: parent.right
    anchors.rightMargin: Theme.size(3)
    anchors.verticalCenter: parent.verticalCenter
    implicitHeight: Theme.size(24)
    icon: field._reveal ? "eye-off" : "eye"
    onClicked: field._reveal = !field._reveal
  }
}
