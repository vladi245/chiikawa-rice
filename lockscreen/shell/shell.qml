import QtQuick
import Quickshell
import Quickshell.Services.Pam
import Quickshell.Wayland

ShellRoot {
  id: root
  property bool preview: Quickshell.env("WOODLAND_LOCK_PREVIEW") === "1"
  property string view: Quickshell.env("WOODLAND_LOCK_VIEW") || Qt.resolvedUrl("FallbackLockView.qml")
  property date now: new Date()
  property string password: ""
  property string status: ""
  property bool error: false
  property bool busy: false
  property bool unlocking: false

  Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
  Timer { id: exitTimer; interval: 350; onTriggered: Qt.quit() }
  Timer {
    id: openDoor
    interval: 1050
    onTriggered: {
      if (root.preview) { root.unlocking = false; root.status = ""; return; }
      session.locked = false;
      exitTimer.start();
    }
  }

  function submit(value) {
    if (root.busy || value.length === 0) return;
    if (root.preview) {
      if (value === "wrong") { root.error = true; root.status = "Incorrect password — try again"; }
      else { root.error = false; root.unlocking = true; openDoor.restart(); }
      return;
    }
    root.password = value;
    root.busy = true;
    root.error = false;
    root.status = "Checking…";
    if (pam.responseRequired) pam.respond(root.password);
    else if (!pam.start()) {
      root.password = "";
      root.busy = false;
      root.error = true;
      root.status = "Authentication unavailable";
    }
  }

  PamContext {
    id: pam
    config: "login"
    onPamMessage: {
      if (responseRequired) {
        if (root.password.length > 0) pam.respond(root.password);
        else { root.busy = false; root.status = "Enter your password"; }
      } else if (messageIsError) {
        root.error = true;
        root.status = message;
      }
    }
    onCompleted: result => {
      root.password = "";
      root.busy = false;
      if (result === PamResult.Success) {
        console.log("Chiikawa lock: authentication succeeded");
        root.error = false;
        root.status = "";
        root.unlocking = true;
        openDoor.start();
      } else {
        root.error = true;
        root.status = "Incorrect password — try again";
      }
    }
    onError: {
      root.password = "";
      root.busy = false;
      root.error = true;
      root.status = "Authentication error";
    }
  }

  Component {
    id: content
    Loader {
      Component.onCompleted: setSource(root.view, { "controller": root })
      // A broken custom view must never leave a lock with no password field.
      onStatusChanged: if (status === Loader.Error && source != Qt.resolvedUrl("FallbackLockView.qml"))
                         setSource(Qt.resolvedUrl("FallbackLockView.qml"), { "controller": root })
    }
  }

  WlSessionLock {
    id: session
    locked: !root.preview
    onSecureChanged: if (secure) console.log("Chiikawa lock: session secured")
    WlSessionLockSurface {
      Loader { anchors.fill: parent; sourceComponent: content }
    }
  }

  FloatingWindow {
    visible: root.preview
    implicitWidth: 960; implicitHeight: 600
    title: "Chiikawa lock preview"
    Loader { anchors.fill: parent; sourceComponent: content }
  }
}
