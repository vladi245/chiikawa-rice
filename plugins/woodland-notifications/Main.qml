import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services.System
import qs.Services.UI
import "../../woodland"

Item {
  id: root
  property var pluginApi: null

  readonly property int maxToasts: 5
  property int serial: 0
  property var callbacks: ({}) // system toast key -> action callback
  property bool dismissingStock: false

  ListModel {
    id: toasts
  }

  function push(entry) {
    entry.key = "t" + (++serial);
    toasts.insert(0, entry);
    while (toasts.count > maxToasts)
      toasts.remove(toasts.count - 1);
    return entry.key;
  }

  function drop(key) {
    for (let i = 0; i < toasts.count; i++) {
      if (toasts.get(i).key === key) {
        toasts.remove(i);
        break;
      }
    }
    delete callbacks[key];
  }

  function takePopups() {
    const queue = NotificationService.popupModel;
    if (queue.count === 0)
      return;
    for (let i = queue.count - 1; i >= 0; i--) {
      const n = queue.get(i);
      const meta = NotificationService.popupState[n.id]?.metadata;
      push({
             "source": "notification",
             "notificationId": n.id,
             "title": n.summary || n.appName || "",
             "body": n.body || "",
             "appName": n.appName || "",
             "image": n.cachedImage || n.originalImage || "",
             "glyph": "",
             "urgency": n.urgency ?? 1,
             "kind": "notice",
             "actionsJson": n.actionsJson || "[]",
             "duration": meta ? meta.duration : 8000
           });
    }
    queue.remove(0, queue.count);
  }

  Connections {
    target: NotificationService.popupModel
    function onRowsInserted() {
      Qt.callLater(root.takePopups);
    }
  }

  function activate(entry, actionId) {
    const id = entry.notificationId;
    let actions = [];
    try {
      actions = JSON.parse(entry.actionsJson || "[]");
    } catch (e) {}
    if (actionId) {
      NotificationService.invokeActionAndSuppressClose(id, actionId);
    } else if (actions.some(a => a.identifier === "default")) {
      if (!NotificationService.invokeActionAndSuppressClose(id, "default"))
        NotificationService.focusSenderWindow(entry.appName);
    } else {
      NotificationService.focusSenderWindow(entry.appName);
    }
  }

  Connections {
    target: ToastService
    function onNotify(title, description, icon, type, duration, actionLabel, actionCallback) {
      const key = root.push({
                              "source": "system",
                              "notificationId": "",
                              "title": title || "",
                              "body": description || "",
                              "appName": "",
                              "image": "",
                              "glyph": icon || (type === "error" ? "alert-circle" : (type === "warning" ? "alert-triangle" : "info-circle")),
                              "urgency": type === "error" ? 2 : 1,
                              "kind": type || "notice",
                              "actionsJson": actionLabel ? JSON.stringify([{ "identifier": "callback", "text": actionLabel }]) : "[]",
                              "duration": duration > 0 ? duration : 3000
                            });
      if (actionCallback)
        root.callbacks[key] = actionCallback;
      // Hide Noctalia's copy before it paints.
      Qt.callLater(() => {
                     root.dismissingStock = true;
                     ToastService.dismissToast();
                     root.dismissingStock = false;
                   });
    }
    function onDismiss() {
      if (root.dismissingStock)
        return;
      for (let i = 0; i < toasts.count; i++) {
        if (toasts.get(i).source === "system") {
          root.drop(toasts.get(i).key);
          break;
        }
      }
    }
  }

  Variants {
    model: {
      const chosen = Quickshell.screens.filter(s => (Settings.data.notifications.monitors || []).includes(s.name));
      return chosen.length > 0 ? chosen : Quickshell.screens;
    }

    delegate: PanelWindow {
      id: window
      required property ShellScreen modelData
      screen: modelData

      readonly property string location: Settings.data.notifications.location || "top_right"
      readonly property bool atTop: !location.startsWith("bottom")
      readonly property bool atLeft: location.endsWith("_left")
      readonly property bool centered: location === "top" || location === "bottom"
      readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)
      readonly property real barSize: Style.getBarHeightForScreen(screen?.name)
      readonly property int gap: Woodland.size(12)
      readonly property int shadow: Woodland.size(18)

      visible: toasts.count > 0
      color: "transparent"
      WlrLayershell.namespace: "woodland-toasts-" + (screen?.name || "unknown")
      WlrLayershell.layer: Settings.data.notifications.overlayLayer ? WlrLayer.Overlay : WlrLayer.Top
      WlrLayershell.exclusionMode: ExclusionMode.Ignore
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      anchors.top: atTop
      anchors.bottom: !atTop
      anchors.left: atLeft
      anchors.right: !atLeft && !centered
      margins.top: atTop ? (barPosition === "top" ? barSize : 0) + gap - shadow : 0
      margins.bottom: !atTop ? (barPosition === "bottom" ? barSize : 0) + gap - shadow : 0
      margins.left: atLeft ? gap - shadow : 0
      margins.right: !atLeft && !centered ? gap - shadow : 0

      implicitWidth: Woodland.size(380) + shadow * 2
      implicitHeight: Math.max(1, stack.implicitHeight + shadow * 2)

      mask: Region {
        item: stack
      }

      Column {
        id: stack
        x: window.shadow
        y: window.shadow
        spacing: Woodland.size(10)

        move: Transition {
          enabled: Woodland.fx
          NumberAnimation { property: "y"; duration: 260; easing.type: Easing.OutCubic }
        }

        Repeater {
          model: toasts
          delegate: Toast {
            required property var model
            title: model.title
            body: model.body
            appName: model.appName
            image: model.image
            glyph: model.glyph
            urgency: model.urgency
            kind: model.kind
            duration: model.duration
            actions: {
              try {
                return JSON.parse(model.actionsJson || "[]");
              } catch (e) {
                return [];
              }
            }

            onExpired: root.drop(model.key)
            onDismissed: {
              if (model.source === "notification" && Settings.data.notifications.clearDismissed)
                NotificationService.removeFromHistory(model.notificationId);
              root.drop(model.key);
            }
            onClicked: {
              if (model.source === "notification")
                root.activate(model, "");
              else if (root.callbacks[model.key])
                root.callbacks[model.key]();
              leave("expired");
            }
            onAction: identifier => {
                        if (model.source === "notification")
                          root.activate(model, identifier);
                        else if (root.callbacks[model.key])
                          root.callbacks[model.key]();
                        leave("expired");
                      }
          }
        }
      }
    }
  }
}
