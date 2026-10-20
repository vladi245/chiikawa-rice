import QtQuick

Item {
  id: panel

  property var pluginApi: null
  readonly property bool allowAttach: false
  readonly property color panelBackgroundColor: Woodland.night
  property real contentPreferredWidth: Woodland.size(380)
  property real contentPreferredHeight: Woodland.size(420)
  property bool panelAnchorHorizontalCenter: false
  property bool panelAnchorVerticalCenter: false

  property alias scene: scene
  property real padding: Woodland.size(18)
  property real spacing: Woodland.size(12)
  default property alias content: body.data

  readonly property var openScreen: pluginApi?.panelOpenScreen ?? null

  function close() {
    pluginApi?.closePanel(pluginApi.panelOpenScreen);
  }

  Scene {
    id: scene
    anchors.fill: parent
  }

  Column {
    id: body
    x: panel.padding
    y: panel.padding
    width: panel.width - panel.padding * 2
    height: panel.height - panel.padding * 2
    spacing: panel.spacing
  }
}
