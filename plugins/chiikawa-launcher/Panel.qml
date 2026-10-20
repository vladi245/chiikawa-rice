import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Services.Compositor
import qs.Widgets
import "../../chiikawa"

Item {
  id: root
  property var pluginApi: null

  readonly property bool allowAttach: false
  readonly property bool panelAnchorHorizontalCenter: true
  readonly property bool panelAnchorVerticalCenter: true
  readonly property color panelBackgroundColor: Woodland.night
  readonly property real contentPreferredWidth: Woodland.size(560)
  readonly property real contentPreferredHeight: Woodland.size(540)

  readonly property int iconSize: Woodland.size(30)
  readonly property int rowHeight: Woodland.size(50)

  readonly property var launches: pluginApi?.pluginSettings?.launches ?? ({})
  readonly property var apps: {
    const seen = {};
    return (DesktopEntries.applications.values || []).filter(app => {
      if (!app || app.noDisplay || app.hidden || seen[app.id])
        return false;
      seen[app.id] = true;
      return true;
    });
  }
  property string query: ""
  readonly property var results: {
    const q = query.trim();
    if (q === "")
      return apps.slice().sort((a, b) => (launches[b.id] || 0) - (launches[a.id] || 0) || a.name.localeCompare(b.name));
    return FuzzySort.go(q, apps, {
                          "keys": ["name", "genericName", "comment"],
                          "limit": 40
                        }).map(r => r.obj);
  }
  property int resultsRevision: 0
  onResultsChanged: {
    resultsRevision++;
    list.currentIndex = 0;
    list.positionViewAtBeginning();
  }

  CastFile {
    id: castFile
  }
  readonly property string who: castFile.who("launcher")

  property bool launching: false
  property bool typing: false
  readonly property string mood: launching ? "happy" : (results.length === 0 ? "cry" : (typing ? "wow" : "idle"))

  function select(index) {
    if (list.count === 0)
      return;
    list.currentIndex = Math.max(0, Math.min(list.count - 1, index));
    list.positionViewAtIndex(list.currentIndex, ListView.Contain);
  }

  function close() {
    pluginApi?.closePanel(pluginApi.panelOpenScreen);
  }

  function launch(app) {
    if (!app)
      return;
    const counts = Object.assign({}, launches);
    counts[app.id] = (counts[app.id] || 0) + 1;
    pluginApi.pluginSettings.launches = counts;
    pluginApi.saveSettings();

    launching = true;
    peek.boing();
    launchTimer.app = app;
    launchTimer.restart();
  }

  function spawn(app) {
    const args = Array.from(app.command || []);
    const quoted = args.some(a => /["' ]/.test(String(a)));
    const terminal = Settings.data.appLauncher.terminalCommand.trim();
    if (app.execute && quoted)
      app.execute();
    else if (app.runInTerminal && terminal !== "")
      CompositorService.spawn(terminal.split(" ").concat(args));
    else if (args.length > 0)
      CompositorService.spawn(args);
    else if (app.execute)
      app.execute();
  }

  function handleKey(event) {
    const page = Math.max(1, Math.floor(list.height / (rowHeight + list.spacing)));
    if (event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier)))
      select(list.currentIndex + 1);
    else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab)
      select(list.currentIndex - 1);
    else if (event.key === Qt.Key_PageDown)
      select(list.currentIndex + page);
    else if (event.key === Qt.Key_PageUp)
      select(list.currentIndex - page);
    else if (event.key === Qt.Key_Home && (event.modifiers & Qt.ControlModifier))
      select(0);
    else if (event.key === Qt.Key_End && (event.modifiers & Qt.ControlModifier))
      select(list.count - 1);
    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
      launch(results[list.currentIndex]);
    else if (event.key === Qt.Key_Escape)
      close();
    else
      return;
    event.accepted = true;
  }

  Timer {
    id: launchTimer
    property var app: null
    interval: Woodland.fx ? 320 : 0
    onTriggered: {
      const target = app;
      root.launching = false;
      root.close();
      Qt.callLater(() => root.spawn(target));
    }
  }
  Timer {
    id: typingTimer
    interval: 700
    onTriggered: root.typing = false
  }

  Scene {
    anchors.fill: parent
    rainCount: 60
  }

  Item {
    id: content
    anchors.fill: parent
    anchors.margins: Woodland.size(22)

    Rectangle {
      id: searchRow
      width: parent.width
      height: Woodland.size(50)
      radius: height / 2
      color: Woodland.white
      border.width: 2
      border.color: input.text ? Woodland.windowLight : Woodland.line
      Behavior on border.color {
        ColorAnimation { duration: 200 }
      }

      Friend {
        id: peek
        width: Woodland.size(40)
        anchors.left: parent.left
        anchors.leftMargin: Woodland.size(8)
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: Woodland.size(1)
        kind: root.who
        role: root.launching ? "happy" : ""
        mood: root.mood
        animated: Woodland.fx
      }

      TextInput {
        id: input
        anchors.left: peek.right
        anchors.leftMargin: Woodland.size(10)
        anchors.right: count.left
        anchors.rightMargin: Woodland.size(10)
        anchors.verticalCenter: parent.verticalCenter
        font.family: Woodland.display
        font.pointSize: 15
        font.weight: Font.Bold
        color: Woodland.mist
        selectionColor: Woodland.blush
        selectedTextColor: Woodland.line
        focus: true
        cursorDelegate: Rectangle {
          width: 2
          radius: 1
          color: Woodland.windowLight
          SequentialAnimation on opacity {
            running: Woodland.fx
            loops: Animation.Infinite
            NumberAnimation { to: 0.2; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
          }
        }
        onTextChanged: {
          root.query = text;
          root.typing = true;
          typingTimer.restart();
        }
        Keys.onPressed: event => root.handleKey(event)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: !input.text
          text: "what shall we do today?"
          font.family: Woodland.display
          font.pointSize: input.font.pointSize
          font.weight: Font.DemiBold
          color: Woodland.bark
        }
      }

      Rectangle {
        id: count
        anchors.right: parent.right
        anchors.rightMargin: Woodland.size(10)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(height, countText.implicitWidth + Woodland.size(14))
        height: Woodland.size(26)
        radius: height / 2
        color: Woodland.blush
        border.width: 1.5
        border.color: Woodland.line
        Text {
          id: countText
          anchors.centerIn: parent
          text: root.results.length
          font.family: Woodland.font
          font.pointSize: 8.5
          font.weight: Font.Bold
          color: Woodland.line
        }
      }
    }

    Item {
      id: resultsArea
      anchors.top: searchRow.bottom
      anchors.topMargin: Woodland.size(14)
      anchors.bottom: footer.top
      anchors.bottomMargin: Woodland.size(8)
      width: parent.width
      clip: true

      Rectangle {
        id: sticker
        property real contentPos: list.currentItem ? list.currentItem.y : 0
        x: Woodland.size(2)
        width: list.width - Woodland.size(4)
        height: root.rowHeight
        y: contentPos - list.contentY
        visible: list.count > 0
        radius: height / 2
        color: Qt.alpha(Woodland.blush, 0.75)
        border.width: 2
        border.color: Woodland.line
        Behavior on contentPos {
          enabled: Woodland.fx
          SpringAnimation { spring: 4.5; damping: 0.32; epsilon: 0.25 }
        }

        Text {
          anchors.right: parent.right
          anchors.rightMargin: Woodland.size(16)
          anchors.verticalCenter: parent.verticalCenter
          text: "⏎"
          font.family: Woodland.font
          font.pointSize: 11
          color: Woodland.line
          opacity: 0.6
        }
      }

      NListView {
        id: list
        anchors.fill: parent
        model: root.results
        spacing: Woodland.size(4)
        currentIndex: 0
        reserveScrollbarSpace: false
        horizontalPolicy: ScrollBar.AlwaysOff
        verticalPolicy: ScrollBar.AlwaysOff
        gradientColor: "transparent"
        wheelScrollMultiplier: 4.0
        cacheBuffer: Math.max(0, height * 2)

        delegate: Item {
          id: row
          required property var modelData
          required property int index
          width: list.width
          height: root.rowHeight

          readonly property real lit: Math.max(0, 1 - Math.abs(sticker.contentPos - y) / height)

          Connections {
            target: root
            function onResultsRevisionChanged() {
              if (Woodland.fx && row.index < 10)
                enter.restart();
            }
          }
          Component.onCompleted: if (Woodland.fx && index < 10)
                                   enter.start()

          SequentialAnimation {
            id: enter
            PropertyAction { target: rowContent; property: "opacity"; value: 0 }
            PropertyAction { target: rowContent; property: "scale"; value: 0.85 }
            PauseAnimation { duration: row.index * 30 }
            ParallelAnimation {
              NumberAnimation { target: rowContent; property: "opacity"; to: 1; duration: 220 }
              NumberAnimation { target: rowContent; property: "scale"; to: 1; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2 }
            }
          }

          Item {
            id: rowContent
            width: parent.width
            height: parent.height

            readonly property string iconSource: Quickshell.iconPath(row.modelData.icon || "", true) || Quickshell.iconPath("application-x-executable", true) || ""

            Image {
              id: icon
              anchors.left: parent.left
              anchors.leftMargin: Woodland.size(18)
              anchors.verticalCenter: parent.verticalCenter
              width: root.iconSize
              height: width
              sourceSize: Qt.size(width * 2, height * 2)
              source: rowContent.iconSource
              visible: rowContent.iconSource !== ""
              asynchronous: true
              smooth: true
              scale: 1 + row.lit * 0.14
              rotation: row.lit > 0.95 ? wiggle.angle : 0
            }

            Rectangle {
              anchors.fill: icon
              visible: rowContent.iconSource === ""
              radius: width / 2
              color: Woodland.usagi
              border.width: 1.5
              border.color: Woodland.line
              Text {
                anchors.centerIn: parent
                text: (row.modelData.name || "?").charAt(0).toUpperCase()
                font.family: Woodland.display
                font.pointSize: 12
                font.weight: Font.Black
                color: Woodland.line
              }
            }

            Column {
              anchors.left: icon.right
              anchors.leftMargin: Woodland.size(14)
              anchors.right: parent.right
              anchors.rightMargin: Woodland.size(44)
              anchors.verticalCenter: parent.verticalCenter
              spacing: 0

              Text {
                width: parent.width
                text: row.modelData.name
                elide: Text.ElideRight
                font.family: Woodland.display
                font.pointSize: 11.5
                font.weight: row.lit > 0.5 ? Font.ExtraBold : Font.DemiBold
                color: row.lit > 0.5 ? Woodland.line : Woodland.fog
              }
              Text {
                width: parent.width
                visible: text !== ""
                text: (row.modelData.genericName || row.modelData.comment || "").toLowerCase()
                elide: Text.ElideRight
                font.family: Woodland.font
                font.pointSize: 7.5
                color: Woodland.bark
              }
            }
          }

          HoverHandler {
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: if (hovered && !list.moving)
                                list.currentIndex = row.index
          }
          TapHandler {
            onTapped: {
              list.currentIndex = row.index;
              root.launch(row.modelData);
            }
          }
        }
      }

      QtObject {
        id: wiggle
        property real angle: 0
      }
      SequentialAnimation {
        running: Woodland.fx && root.visible && list.count > 0
        loops: Animation.Infinite
        NumberAnimation { target: wiggle; property: "angle"; to: -7; duration: 140; easing.type: Easing.InOutSine }
        NumberAnimation { target: wiggle; property: "angle"; to: 6; duration: 180; easing.type: Easing.InOutSine }
        NumberAnimation { target: wiggle; property: "angle"; to: 0; duration: 140; easing.type: Easing.InOutSine }
        PauseAnimation { duration: 1600 }
      }

      Column {
        anchors.centerIn: parent
        visible: list.count === 0
        spacing: Woodland.size(8)
        Friend {
          anchors.horizontalCenter: parent.horizontalCenter
          width: Woodland.size(72)
          kind: root.who
          role: "cry"
          mood: "cry"
          animated: Woodland.fx && list.count === 0
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "nothing here by that name…"
          font.family: Woodland.display
          font.pointSize: 11
          font.weight: Font.Bold
          color: Woodland.fog
        }
      }
    }

    Text {
      id: footer
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      text: "↑↓ choose   ⏎ ya-ha!   esc bye-bye"
      font.family: Woodland.font
      font.pointSize: 7.5
      color: Woodland.bark
    }
  }

  Component.onCompleted: input.forceActiveFocus()
}
