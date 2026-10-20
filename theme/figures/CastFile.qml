import QtQuick
import Quickshell
import Quickshell.Io
import "cast.js" as Cast

Item {
  id: store

  readonly property var kinds: Cast.kinds
  readonly property var names: Cast.names
  property var cast: Cast.defaults

  function who(place) {
    return cast[place] ?? Cast.defaults[place];
  }
  function has(kind, role) {
    return Cast.has(kind, role);
  }
  function idles(kind) {
    return Cast.idles(kind);
  }
  function set(place, value) {
    const next = Object.assign({}, cast);
    next[place] = value;
    cast = next;
    file.setText(JSON.stringify(next, null, 2) + "\n");
  }

  FileView {
    id: file
    path: Quickshell.env("HOME") + "/.config/rice/chiikawa-cast.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try {
        store.cast = Object.assign({}, Cast.defaults, JSON.parse(text()));
      } catch (e) {
        store.cast = Cast.defaults;
      }
    }
  }
}
