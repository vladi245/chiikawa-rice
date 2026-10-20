import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Services.Media
import "../../chiikawa"

CPanel {
  id: root

  readonly property var outputs: AudioService.sinks || []
  readonly property var inputs: AudioService.sources || []
  readonly property var apps: (AudioService.appStreams || []).filter(n => !isCapture(n))

  contentPreferredWidth: Theme.size(400)
  contentPreferredHeight: Math.min(Theme.size(640), header.height + Theme.size(70) + body.implicitHeight)
  scene.density: 18

  PwObjectTracker {
    objects: root.apps.concat(root.outputs, root.inputs)
  }

  function isCapture(node) {
    const p = node?.properties || {};
    const cls = p["media.class"] || "";
    return p["stream.capture.sink"] !== undefined || cls.includes("Capture") || cls.startsWith("Stream/Input") || p["media.role"] === "Capture";
  }

  function nodeName(node) {
    return node?.description || node?.nickname || node?.name || "unknown";
  }

  // Devices on one card share a long prefix ("Meteor Lake-P HD Audio
  // Controller ..."); show the part that tells them apart.
  function sharedPrefix(nodes) {
    const names = nodes.map(n => nodeName(n).split(" "));
    if (names.length < 2)
      return "";
    let n = 0;
    while (names.every(w => n < w.length - 1 && w[n] === names[0][n]))
      n++;
    return names[0].slice(0, n).join(" ");
  }
  function shortName(node, prefix) {
    const full = nodeName(node);
    return prefix && full.startsWith(prefix + " ") ? full.slice(prefix.length + 1) : full;
  }
  readonly property string outputPrefix: sharedPrefix(outputs)
  readonly property string inputPrefix: sharedPrefix(inputs)

  function appName(node) {
    const p = node?.properties || {};
    const binary = (p["application.process.binary"] || "").split("/").pop();
    const entry = binary ? ThemeIcons.findAppEntry(binary.toLowerCase()) : null;
    return entry?.name || p["application.name"] || node?.description || node?.name || "unknown app";
  }
  function appIcon(node) {
    const p = node?.properties || {};
    const names = [p["application.icon-name"], (p["application.process.binary"] || "").split("/").pop(), (p["application.name"] || "").toLowerCase()];
    for (const n of names) {
      if (!n)
        continue;
      const entry = ThemeIcons.findAppEntry(n.toLowerCase());
      const path = Quickshell.iconPath(entry?.icon || n, true);
      if (path)
        return path;
    }
    return "";
  }

  function format(node) {
    const p = node?.properties || {};
    const bits = [];
    if (p["audio.channels"])
      bits.push(p["audio.channels"] === "2" ? "stereo" : p["audio.channels"] + "ch");
    if (p["audio.rate"])
      bits.push((Number(p["audio.rate"]) / 1000) + " kHz");
    return bits.join(" · ");
  }

  component Caption: Text {
    font.family: Theme.font
    font.pointSize: 8
    color: Theme.inkFaint
  }

  Header {
    id: header
    icon: AudioService.muted ? "volume-off" : "volume"
    title: "Sound"
    subtitle: root.shortName(AudioService.sink, root.outputPrefix) + (root.apps.length ? `  ·  ${root.apps.length} playing` : "")
    lit: !AudioService.muted

    CToggle {
      anchors.verticalCenter: parent.verticalCenter
      checked: !AudioService.muted
      onToggled: on => AudioService.setOutputMuted(!on)
    }
  }

  Flickable {
    width: parent.width
    height: parent.height - header.height - parent.spacing
    contentHeight: body.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: body
      width: parent.width
      spacing: Theme.size(10)

      Item {
        width: 1
        height: Theme.size(2)
      }

      VolumeHero {
        sink: AudioService.sink
        volume: AudioService.volume
        muted: AudioService.muted
        playing: root.apps.some(n => !(n?.audio?.muted ?? false))
        deviceName: root.shortName(AudioService.sink, root.outputPrefix)
        onToggleMute: AudioService.setOutputMuted(!AudioService.muted)
      }

      CSlider {
        icon: AudioService.muted ? "volume-off" : "volume"
        value: AudioService.volume
        maximum: AudioService.maxVolume
        step: AudioService.stepVolume
        muted: AudioService.muted
        onMoved: v => AudioService.setVolume(v)
        onIconClicked: AudioService.setOutputMuted(!AudioService.muted)
      }

      CSlider {
        visible: AudioService.hasInput
        icon: AudioService.inputMuted ? "microphone-off" : "microphone"
        value: AudioService.inputVolume
        maximum: AudioService.maxVolume
        step: AudioService.stepVolume
        muted: AudioService.inputMuted
        onMoved: v => AudioService.setInputVolume(v)
        onIconClicked: AudioService.setInputMuted(!AudioService.inputMuted)
      }

      Caption {
        text: "applications"
      }

      Caption {
        visible: root.apps.length === 0
        text: "  nothing is playing"
        font.italic: true
        color: Qt.alpha(Theme.inkSoft, 0.6)
      }

      Repeater {
        model: root.apps
        delegate: Column {
          id: app
          required property var modelData
          readonly property var audio: modelData?.audio ?? null
          readonly property bool muted: audio?.muted ?? false
          readonly property string iconPath: root.appIcon(modelData)
          readonly property string playing: modelData?.properties?.["media.name"] || ""
          width: parent.width
          spacing: 0

          CRow {
            iconSource: app.iconPath
            icon: app.iconPath === "" ? "music" : ""
            title: root.appName(app.modelData)
            subtitle: app.playing
            interactive: false
            active: !app.muted
            implicitHeight: Theme.size(app.playing ? 40 : 30)
          }
          CSlider {
            icon: app.muted ? "volume-off" : "volume-2"
            value: app.audio?.volume ?? 0
            muted: app.muted
            onMoved: v => AudioService.setPanelAppStreamVolume(app.modelData, v)
            onIconClicked: AudioService.setPanelAppStreamMuted(app.modelData, !app.muted)
          }
        }
      }

      Caption {
        text: "outputs"
      }

      Column {
        width: parent.width
        spacing: 0
        Repeater {
          model: root.outputs
          delegate: CRow {
            required property var modelData
            icon: modelData === AudioService.sink ? "volume" : "device-speaker"
            title: root.shortName(modelData, root.outputPrefix)
            subtitle: root.outputPrefix
            detail: modelData === AudioService.sink ? root.format(modelData) : ""
            active: modelData === AudioService.sink
            onClicked: AudioService.setAudioSink(modelData)
          }
        }
      }

      Caption {
        visible: root.inputs.length > 0
        text: "inputs"
      }

      Column {
        width: parent.width
        spacing: 0
        Repeater {
          model: root.inputs
          delegate: CRow {
            required property var modelData
            icon: "microphone"
            title: root.shortName(modelData, root.inputPrefix)
            subtitle: root.inputPrefix
            detail: modelData === AudioService.source ? root.format(modelData) : ""
            active: modelData === AudioService.source
            onClicked: AudioService.setAudioSource(modelData)
          }
        }
      }
    }
  }
}
