import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.Commons
import qs.Services.System
import qs.Widgets
import "../../woodland"

WPanel {
  id: root

  readonly property int total: NotificationService.historyModel.count
  property real openedSeen: 0
  readonly property int awayCount: {
    const model = NotificationService.historyModel;
    let n = 0;
    for (let i = 0; i < model.count; i++)
      if (stamp(model.get(i).timestamp) > openedSeen)
        n++;
    return n;
  }
  property string appFilter: ""
  property int historyRevision: 0

  Connections {
    target: NotificationService.historyModel
    function onDataChanged() {
      root.historyRevision++;
    }
  }

  readonly property var entries: {
    historyRevision;
    const model = NotificationService.historyModel;
    const out = [];
    for (let i = 0; i < model.count; i++) {
      const e = model.get(i);
      if (appFilter !== "" && (e.appName || "other") !== appFilter)
        continue;
      out.push({
                 "id": e.id,
                 "appName": e.appName,
                 "summary": e.summary,
                 "body": e.body,
                 "urgency": e.urgency,
                 "timestamp": e.timestamp,
                 "cachedImage": e.cachedImage,
                 "originalImage": e.originalImage,
                 "actionsJson": e.actionsJson
               });
    }
    return out;
  }
  property string expandedId: ""

  readonly property var apps: {
    const counts = {};
    const model = NotificationService.historyModel;
    for (let i = 0; i < model.count; i++) {
      const name = model.get(i).appName || "other";
      counts[name] = (counts[name] || 0) + 1;
    }
    return Object.keys(counts).sort((a, b) => counts[b] - counts[a]).slice(0, 3);
  }

  contentPreferredWidth: Woodland.size(420)
  contentPreferredHeight: Woodland.size(540)
  scene.rainCount: 22

  Component.onCompleted: {
    openedSeen = NotificationService.lastSeenTs;
    NotificationService.updateLastSeenTs();
  }
  Component.onDestruction: NotificationService.updateLastSeenTs()

  function stamp(ts) {
    return ts instanceof Date ? ts.getTime() : Number(ts);
  }

  function ago(ts) {
    const t = stamp(ts);
    const s = Math.max(0, (Time.now.getTime() - t) / 1000);
    if (s < 60)
      return "now";
    if (s < 3600)
      return Math.floor(s / 60) + "m ago";
    if (s < 86400)
      return Math.floor(s / 3600) + "h ago";
    if (s < 86400 * 7)
      return Math.floor(s / 86400) + "d ago";
    return Qt.formatDate(new Date(t), "d MMM");
  }

  function actionsOf(actionsJson) {
    try {
      return JSON.parse(actionsJson || "[]");
    } catch (e) {
      return [];
    }
  }

  Header {
    icon: NotificationService.doNotDisturb ? "bell-off" : "bell"
    title: "Notifications"
    subtitle: {
      if (root.total === 0)
        return NotificationService.doNotDisturb ? "quiet hours" : "nothing yet";
      const base = root.total + (root.total === 1 ? " message" : " messages");
      return base + (root.awayCount > 0 ? " · " + root.awayCount + " new" : (NotificationService.doNotDisturb ? " · quiet hours" : ""));
    }
    lit: !NotificationService.doNotDisturb && root.total > 0

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "quiet"
      font.family: Woodland.font
      font.pointSize: 8
      color: NotificationService.doNotDisturb ? Woodland.windowLight : Woodland.bark
    }
    WToggle {
      anchors.verticalCenter: parent.verticalCenter
      checked: NotificationService.doNotDisturb
      onToggled: on => NotificationService.doNotDisturb = on
    }
    WButton {
      anchors.verticalCenter: parent.verticalCenter
      icon: "trash"
      enabled: root.total > 0
      onClicked: NotificationService.clearHistory()
    }
  }

  Flow {
    width: parent.width
    visible: root.apps.length > 1
    spacing: Woodland.size(6)

    WButton {
      text: "all"
      accent: root.appFilter === ""
      onClicked: root.appFilter = ""
    }
    Repeater {
      model: root.apps
      delegate: WButton {
        required property string modelData
        text: modelData.split(" ")[0].toLowerCase()
        accent: root.appFilter === modelData
        onClicked: root.appFilter = root.appFilter === modelData ? "" : modelData
      }
    }
  }

  Item {
    id: listArea
    width: parent.width
    height: parent.height - y

    NListView {
      id: list
      anchors.fill: parent
      model: root.entries
      spacing: Woodland.size(2)
      reserveScrollbarSpace: false
      horizontalPolicy: ScrollBar.AlwaysOff
      verticalPolicy: ScrollBar.AlwaysOff
      gradientColor: "transparent"
      wheelScrollMultiplier: 4.0
      cacheBuffer: Math.max(0, height * 2)

      delegate: Item {
        id: entry
        required property int index
        required property var modelData
        readonly property var model: modelData
        readonly property bool hot: hover.hovered
        readonly property var actions: root.actionsOf(model.actionsJson)
        readonly property bool critical: model.urgency === 2
        readonly property bool fresh: root.stamp(model.timestamp) > root.openedSeen
        readonly property bool expanded: root.expandedId === model.id
        readonly property bool expandable: actions.length > 0 || bodyText.truncated || bodyText.lineCount > 2
        // The cached copy can be pruned; fall back to the original image.
        property bool cacheMissing: false
        readonly property string image: (!cacheMissing && model.cachedImage) || model.originalImage || ""
        property real glow: hot ? 1 : 0
        Behavior on glow {
          NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        width: list.width
        height: Math.max(Woodland.size(58), textColumn.implicitHeight + Woodland.size(18))

        Component.onCompleted: if (Woodland.fx && index < 10)
                                 enter.start()
        SequentialAnimation {
          id: enter
          PropertyAction { target: content; property: "opacity"; value: 0 }
          PropertyAction { target: content; property: "x"; value: Woodland.size(14) }
          PauseAnimation { duration: entry.index * 30 }
          ParallelAnimation {
            NumberAnimation { target: content; property: "opacity"; to: 1; duration: 420; easing.type: Easing.OutCubic }
            NumberAnimation { target: content; property: "x"; to: 0; duration: 420; easing.type: Easing.OutCubic }
          }
        }

        Item {
          id: content
          width: parent.width
          height: parent.height

          Rectangle {
            anchors.fill: parent
            radius: Woodland.size(4)
            opacity: entry.glow
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0.0; color: Qt.alpha(Woodland.windowLight, 0.16) }
              GradientStop { position: 0.5; color: Qt.alpha(Woodland.windowLight, 0.04) }
              GradientStop { position: 1.0; color: "transparent" }
            }
          }

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: parent.height * 0.55
            radius: 1
            color: entry.critical ? Woodland.ember : Woodland.windowLight
            opacity: entry.critical ? Math.max(0.7, entry.glow) : Math.max(entry.expanded ? 0.6 : 0, entry.glow)
            layer.enabled: Woodland.fx && opacity > 0
            layer.effect: MultiEffect {
              shadowEnabled: true
              shadowColor: entry.critical ? Woodland.ember : Woodland.windowLight
              shadowBlur: 1
              shadowOpacity: 0.9
              shadowHorizontalOffset: 0
              shadowVerticalOffset: 0
              blurMax: 18
            }
          }

          Item {
            id: badge
            anchors.left: parent.left
            anchors.leftMargin: Woodland.size(12)
            anchors.top: parent.top
            anchors.topMargin: Woodland.size(10)
            width: Woodland.size(30)
            height: width

            Image {
              id: picture
              anchors.fill: parent
              visible: false
              source: entry.image
              sourceSize: Qt.size(width * 2, height * 2)
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              onStatusChanged: if (status === Image.Error && !entry.cacheMissing && entry.model.originalImage && source.toString() === entry.model.cachedImage)
                                 entry.cacheMissing = true
            }
            Rectangle {
              id: badgeMask
              anchors.fill: parent
              radius: Woodland.size(6)
              visible: false
              layer.enabled: true
            }
            MultiEffect {
              anchors.fill: parent
              source: picture
              visible: picture.status === Image.Ready
              maskEnabled: true
              maskSource: badgeMask
              saturation: -0.7 + entry.glow * 0.7
              brightness: -0.12 + entry.glow * 0.12
            }
            Rectangle {
              anchors.fill: parent
              visible: picture.status !== Image.Ready
              radius: Woodland.size(6)
              color: Qt.alpha(Woodland.moss, 0.7)
              border.width: 1
              border.color: Qt.alpha(Woodland.fog, 0.3)
              Text {
                anchors.centerIn: parent
                text: (entry.model.appName || "?").charAt(0).toUpperCase()
                font.family: Woodland.font
                font.pointSize: 11
                font.weight: Font.Bold
                color: Woodland.lit(Woodland.fog, entry.glow)
              }
            }
          }

          Column {
            id: textColumn
            anchors.left: badge.right
            anchors.leftMargin: Woodland.size(12)
            anchors.right: dismiss.left
            anchors.rightMargin: Woodland.size(6)
            anchors.top: parent.top
            anchors.topMargin: Woodland.size(9)
            spacing: Woodland.size(2)

            Row {
              width: parent.width
              spacing: Woodland.size(6)
              Rectangle {
                visible: entry.fresh
                anchors.verticalCenter: parent.verticalCenter
                width: Woodland.size(5)
                height: width
                radius: width / 2
                color: Woodland.ember
              }
              Text {
                width: parent.width - (entry.fresh ? Woodland.size(11) : 0)
                text: (entry.model.appName || "") + "  ·  " + root.ago(entry.model.timestamp) + (entry.critical ? "  ·  urgent" : "")
                elide: Text.ElideRight
                font.family: Woodland.font
                font.pointSize: 7.5
                color: entry.critical ? Woodland.ember : Woodland.bark
              }
            }
            Text {
              width: parent.width
              text: entry.model.summary || ""
              elide: Text.ElideRight
              font.family: Woodland.font
              font.pointSize: 9.5
              color: entry.critical ? Woodland.lit(Woodland.ember, entry.glow * 0.5) : Woodland.lit(Woodland.fog, entry.glow)
            }
            Text {
              id: bodyText
              width: parent.width
              visible: text !== ""
              text: entry.model.body || ""
              wrapMode: Text.Wrap
              maximumLineCount: entry.expanded ? 40 : 2
              elide: Text.ElideRight
              textFormat: Text.PlainText
              font.family: Woodland.font
              font.pointSize: 8
              lineHeight: 1.1
              color: Woodland.lit(Woodland.bark, entry.glow * 0.6 + (entry.expanded ? 0.3 : 0))
            }
            Flow {
              width: parent.width
              visible: entry.expanded && entry.actions.length > 0
              spacing: Woodland.size(6)
              topPadding: Woodland.size(4)
              Repeater {
                model: entry.expanded ? entry.actions : []
                delegate: WButton {
                  required property var modelData
                  text: modelData.identifier === "default" && (modelData.text === "Action" || !modelData.text) ? "open" : modelData.text.toLowerCase()
                  accent: modelData.identifier === "default"
                  onClicked: {
                    if (NotificationService.invokeAction(entry.model.id, modelData.identifier))
                      root.close();
                  }
                }
              }
            }
          }

          WButton {
            id: dismiss
            anchors.right: parent.right
            anchors.rightMargin: Woodland.size(8)
            anchors.top: parent.top
            anchors.topMargin: Woodland.size(10)
            icon: "x"
            opacity: entry.hot ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
              NumberAnimation { duration: 160 }
            }
            onClicked: NotificationService.removeFromHistory(entry.model.id)
          }
        }

        HoverHandler {
          id: hover
          cursorShape: entry.expandable ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
        TapHandler {
          enabled: entry.expandable
          onTapped: root.expandedId = entry.expanded ? "" : entry.model.id
        }
      }
    }

    Text {
      anchors.centerIn: parent
      anchors.verticalCenterOffset: -Woodland.size(40)
      visible: root.total === 0
      text: NotificationService.doNotDisturb ? "the valley is quiet, by request" : "the valley is quiet"
      font.family: Woodland.font
      font.italic: true
      font.pointSize: 10
      color: Qt.alpha(Woodland.fog, 0.7)
    }
  }
}
