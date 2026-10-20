import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services.Compositor
import qs.Services.System
import qs.Services.UI
import "../../chiikawa"

// Needs this niri layer rule:
//   layer-rule { match namespace="^chiikawa-backdrop"; place-within-backdrop true; }
Item {
  id: root
  property var pluginApi: null

  readonly property bool overviewOpen: CompositorService.overviewActive

  Variants {
    model: Quickshell.screens

    delegate: Scope {
      id: perScreen
      required property ShellScreen modelData

      // Rebuilt when niri reports a change (not as bindings, which looped).
      property var spaces: []
      property var windowsBySpace: ({})

      function refresh() {
        const list = [];
        const ws = CompositorService.workspaces;
        for (let i = 0; i < ws.count; i++) {
          const w = ws.get(i);
          if (w.output === modelData?.name)
            list.push({ "ws": w, "id": w.id, "idx": w.idx, "name": w.name, "isFocused": w.isFocused, "isActive": w.isActive });
        }
        const map = {};
        const wins = CompositorService.windows;
        for (let i = 0; i < wins.count; i++) {
          const w = wins.get(i);
          (map[w.workspaceId] = map[w.workspaceId] || []).push({ "appId": w.appId, "title": w.title, "isFocused": w.isFocused });
        }
        windowsBySpace = map;
        spaces = list.sort((a, b) => a.idx - b.idx);
      }

      Component.onCompleted: refresh()
      Connections {
        target: CompositorService
        function onWorkspacesChanged() {
          Qt.callLater(perScreen.refresh);
        }
        function onWindowListChanged() {
          Qt.callLater(perScreen.refresh);
        }
      }
      Connections {
        target: root
        function onOverviewOpenChanged() {
          if (root.overviewOpen)
            perScreen.refresh();
        }
      }

      readonly property int windowCount: spaces.reduce((sum, s) => sum + (windowsBySpace[s.id] || []).length, 0)

      PanelWindow {
        id: backdrop
        screen: perScreen.modelData

        color: Theme.paper
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "chiikawa-backdrop-" + (screen?.name || "unknown")
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Image {
          id: wallpaperImage
          anchors.fill: parent
          source: WallpaperService.getWallpaper(backdrop.screen?.name ?? "") || ""
          // getWallpaper() isn't reactive, so follow wallpaper changes by hand.
          Connections {
            target: WallpaperService
            function onWallpaperChanged(screenName, path) {
              if (screenName === (backdrop.screen?.name ?? ""))
                wallpaperImage.source = path;
            }
          }
          sourceSize: Qt.size(backdrop.width, backdrop.height)
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          layer.enabled: true
          layer.effect: MultiEffect {
            blurEnabled: true
            blur: 0.8
            blurMax: 64
            brightness: Theme.backdropBrightness
            saturation: Theme.backdropSaturation
          }
        }

        Rectangle {
          anchors.fill: parent
          gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Theme.paper, 0.45) }
            GradientStop { position: 0.4; color: Qt.alpha(Theme.paper, 0.35) }
            GradientStop { position: 1.0; color: Qt.alpha(Theme.paper, 0.75) }
          }
        }

        Scene {
          anchors.fill: parent
          sky: false
          grass: false
          rainCount: 140
          running: Theme.fx && root.overviewOpen
        }
      }

      PanelWindow {
        id: strip
        screen: perScreen.modelData
        visible: root.overviewOpen && perScreen.spaces.length > 0

        color: "transparent"
        anchors.bottom: true
        margins.bottom: Theme.size(26)
        implicitWidth: card.width
        implicitHeight: card.height
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "chiikawa-overview-strip"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
          id: card
          readonly property real pad: Theme.size(12)
          width: Math.min(perScreen.modelData.width - Theme.size(80), content.implicitWidth + pad * 2)
          height: content.implicitHeight + pad * 2
          radius: Theme.size(16)
          color: Qt.alpha(Theme.paper, 0.92)
          border.width: 1
          border.color: Qt.alpha(Theme.inkSoft, 0.35)

          opacity: 0
          scale: 0.96
          Component.onCompleted: appear.start()
          Connections {
            target: root
            function onOverviewOpenChanged() {
              if (root.overviewOpen)
                appear.restart();
            }
          }
          ParallelAnimation {
            id: appear
            NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: card; property: "scale"; from: 0.96; to: 1; duration: 280; easing.type: Easing.OutBack }
          }

          Column {
            id: content
            x: card.pad
            y: card.pad
            spacing: Theme.size(8)

            Row {
              spacing: Theme.size(10)
              Text {
                text: `${HostService.username || "user"}@${HostService.hostName || "host"}`
                font.family: Theme.font
                font.pointSize: 10
                font.weight: Font.Bold
                color: Theme.ink
              }
              Text {
                anchors.baseline: parent.children[0].baseline
                text: `${perScreen.windowCount} ${perScreen.windowCount === 1 ? "window" : "windows"} · ${perScreen.spaces.length} ${perScreen.spaces.length === 1 ? "workspace" : "workspaces"} · ${Qt.formatTime(Time.now, "HH:mm")}`
                font.family: Theme.font
                font.pointSize: 8
                color: Theme.inkFaint
              }
              Text {
                anchors.baseline: parent.children[0].baseline
                text: "drag windows between workspaces · enter to open · esc to leave"
                font.family: Theme.font
                font.pointSize: 7.5
                color: Qt.alpha(Theme.inkSoft, 0.6)
              }
            }

            Row {
              spacing: Theme.size(6)

              Repeater {
                model: perScreen.spaces
                delegate: Rectangle {
                  id: chip
                  required property var modelData
                  required property int index
                  readonly property var wins: perScreen.windowsBySpace[modelData.id] || []
                  readonly property bool lit: modelData.isFocused
                  readonly property bool hot: chipHover.hovered

                  width: chipRow.implicitWidth + Theme.size(20)
                  height: Theme.size(38)
                  radius: Theme.size(10)
                  color: lit ? Qt.alpha(Theme.pink, 0.2) : (hot ? Qt.alpha(Theme.pink, 0.1) : Qt.alpha(Theme.tan, 0.35))
                  border.width: 1
                  border.color: lit ? Qt.alpha(Theme.pink, 0.7) : Qt.alpha(Theme.inkSoft, hot ? 0.5 : 0.2)
                  Behavior on color {
                    ColorAnimation { duration: 180 }
                  }

                  Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: Theme.size(7)

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: chip.modelData.idx
                      font.family: Theme.font
                      font.pointSize: 13
                      font.weight: Font.Bold
                      color: chip.lit ? Theme.pink : Theme.inkSoft
                    }
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      visible: text !== ""
                      text: chip.modelData.name || ""
                      font.family: Theme.font
                      font.pointSize: 8.5
                      color: chip.lit ? Theme.ink : Theme.inkSoft
                    }

                    Repeater {
                      model: chip.wins.slice(0, 5)
                      delegate: Item {
                        required property var modelData
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.size(18)
                        height: width
                        Image {
                          id: appIcon
                          anchors.fill: parent
                          sourceSize: Qt.size(width * 2, height * 2)
                          source: {
                            const id = modelData.appId || "";
                            const entry = id ? ThemeIcons.findAppEntry(id) : null;
                            return Quickshell.iconPath(entry?.icon || id, true) || Quickshell.iconPath("application-x-executable", true) || "";
                          }
                          visible: false
                        }
                        MultiEffect {
                          anchors.fill: parent
                          source: appIcon
                          saturation: chip.lit || chip.hot ? 0 : -0.7
                          opacity: chip.lit || chip.hot ? 1 : 0.65
                        }
                      }
                    }
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      visible: chip.wins.length > 5 || chip.wins.length === 0
                      text: chip.wins.length === 0 ? "empty" : `+${chip.wins.length - 5}`
                      font.family: Theme.font
                      font.pointSize: 8
                      color: Theme.inkFaint
                    }
                  }

                  HoverHandler {
                    id: chipHover
                    cursorShape: Qt.PointingHandCursor
                  }
                  TapHandler {
                    onTapped: CompositorService.switchToWorkspace(chip.modelData.ws)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
