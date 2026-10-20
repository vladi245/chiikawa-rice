import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Services.Media
import qs.Services.Power
import qs.Services.UI
import qs.Widgets

Item {
  id: root
  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property string screenName: screen?.name ?? ""
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real fontSize: Style.getBarFontSizeForScreen(screenName)
  readonly property bool fx: !Settings.data.general.animationDisabled && !PowerProfileService.noctaliaPerformanceMode
  readonly property string spectrumId: "plugin:vinyl-media:" + (screenName || "unknown")

  readonly property bool hasTrack: MediaService.currentPlayer !== null && MediaService.trackTitle !== ""
  readonly property bool playing: hasTrack && MediaService.isPlaying
  readonly property string label: MediaService.trackArtist ? `${MediaService.trackArtist} — ${MediaService.trackTitle}` : MediaService.trackTitle
  readonly property int discSize: Style.toOdd(capsuleHeight * 0.86)
  readonly property int maxTextWidth: Math.round(capsuleHeight * 6)

  visible: hasTrack
  implicitWidth: hasTrack ? Math.round(discSize + Style.marginS + textWindow.width + Style.margin2S) : 0
  implicitHeight: capsuleHeight

  readonly property bool wantsSpectrum: playing && fx
  onWantsSpectrumChanged: wantsSpectrum ? SpectrumService.registerComponent(spectrumId) : SpectrumService.unregisterComponent(spectrumId)
  Component.onCompleted: if (wantsSpectrum)
                           SpectrumService.registerComponent(spectrumId)
  Component.onDestruction: SpectrumService.unregisterComponent(spectrumId)

  Item {
    id: disc
    width: root.discSize
    height: root.discSize
    x: Style.marginS
    anchors.verticalCenter: parent.verticalCenter

    property real speed: root.playing ? 140 : 0 // degrees per second
    Behavior on speed {
      NumberAnimation { duration: root.playing ? 900 : 1800; easing.type: root.playing ? Easing.OutQuad : Easing.OutCubic }
    }

    FrameAnimation {
      running: root.fx && disc.speed > 0.5
      onTriggered: platter.rotation = (platter.rotation + disc.speed * frameTime) % 360
    }

    Item {
      id: platter
      anchors.fill: parent

      Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Color.mSurfaceVariant
        border.width: 1
        border.color: Qt.alpha(Color.mOutline, 0.9)
      }

      Image {
        id: art
        anchors.fill: parent
        anchors.margins: 1
        source: MediaService.trackArtUrl
        sourceSize: Qt.size(width * 2, height * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
      }

      Rectangle {
        id: discMask
        anchors.fill: art
        radius: width / 2
        visible: false
        layer.enabled: true
      }

      MultiEffect {
        anchors.fill: art
        source: art
        maskEnabled: true
        maskSource: discMask
        visible: art.status === Image.Ready
        saturation: -0.35
      }

      NIcon {
        anchors.centerIn: parent
        visible: art.status !== Image.Ready
        icon: "disc"
        pointSize: root.fontSize
        applyUiScale: false
        color: Color.mOnSurfaceVariant
      }

      Repeater {
        model: 2
        delegate: Rectangle {
          required property int index
          anchors.centerIn: parent
          width: platter.width * (0.78 - index * 0.2)
          height: width
          radius: width / 2
          color: "transparent"
          border.width: 0.6
          border.color: Qt.alpha(Color.mShadow, 0.45)
        }
      }

      Rectangle {
        anchors.centerIn: parent
        width: platter.width * 0.62
        height: 1.2
        rotation: 35
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: "transparent" }
          GradientStop { position: 0.5; color: Qt.alpha(Color.mPrimary, art.status === Image.Ready ? 0.55 : 0.25) }
          GradientStop { position: 1.0; color: "transparent" }
        }
      }

      Rectangle {
        anchors.centerIn: parent
        width: Math.max(3, Math.round(platter.width * 0.18))
        height: width
        radius: width / 2
        color: Color.mSurface
        border.width: 1
        border.color: Qt.alpha(Color.mOnSurfaceVariant, 0.6)
      }
    }

    layer.enabled: root.fx
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Color.mPrimary
      shadowOpacity: root.playing ? 0.45 : 0
      shadowBlur: 0.6
      shadowHorizontalOffset: 0
      shadowVerticalOffset: 0
      blurMax: 12
      Behavior on shadowOpacity {
        NumberAnimation { duration: Style.animationSlow }
      }
    }
  }

  Item {
    id: textWindow
    x: disc.x + disc.width + Style.marginS
    width: Math.min(root.maxTextWidth, labelMetrics.advanceWidth + 2)
    height: root.capsuleHeight
    anchors.verticalCenter: parent.verticalCenter

    TextMetrics {
      id: labelMetrics
      font: label.font
      text: root.label
    }

    Row {
      id: spectrum
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Math.round(root.capsuleHeight * 0.12)
      anchors.horizontalCenter: parent.horizontalCenter
      height: parent.height * 0.76
      spacing: 1.5
      opacity: root.wantsSpectrum && !SpectrumService.isIdle ? 0.16 : 0
      visible: opacity > 0
      Behavior on opacity {
        NumberAnimation { duration: Style.animationSlow }
      }

      readonly property int bars: Math.max(4, Math.floor((textWindow.width + spacing) / (2 + spacing)))
      Repeater {
        model: spectrum.bars
        delegate: Rectangle {
          required property int index
          readonly property var values: SpectrumService.values
          readonly property int band: values.length > 0 ? Math.floor(Math.abs(index - (spectrum.bars - 1) / 2) / (spectrum.bars / 2) * values.length) : 0
          width: 2
          radius: 1
          anchors.bottom: parent.bottom
          height: Math.max(1, spectrum.height * Math.min(1, values[Math.min(band, values.length - 1)] ?? 0))
          color: Color.mPrimary
        }
      }
    }

    Item {
      id: marquee
      anchors.fill: parent
      clip: true
      visible: false
      layer.enabled: true

      readonly property bool scrolls: labelMetrics.advanceWidth + 2 > textWindow.width
      readonly property real loopWidth: labelMetrics.advanceWidth + root.capsuleHeight * 1.5

      Row {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.capsuleHeight * 1.5
        Text {
          id: label
          text: root.label
          font.family: Settings.data.ui.fontDefault
          font.pointSize: root.fontSize * 0.92
          color: Color.mOnSurface
        }
        Text {
          visible: marquee.scrolls
          text: root.label
          font: label.font
          color: Color.mOnSurface
        }
      }

      NumberAnimation {
        target: track
        property: "x"
        running: marquee.scrolls && root.playing && root.fx
        from: 0
        to: -marquee.loopWidth
        duration: marquee.loopWidth * 28
        loops: Animation.Infinite
        onRunningChanged: if (!running)
                            track.x = 0
      }
    }

    Rectangle {
      id: fadeMask
      anchors.fill: parent
      visible: false
      layer.enabled: true
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: marquee.scrolls ? "transparent" : "white" }
        GradientStop { position: 0.14; color: "white" }
        GradientStop { position: 0.86; color: "white" }
        GradientStop { position: 1.0; color: marquee.scrolls ? "transparent" : "white" }
      }
    }

    MultiEffect {
      anchors.fill: parent
      source: marquee
      maskEnabled: true
      maskSource: fadeMask
      opacity: root.playing ? 1 : 0.6
      Behavior on opacity {
        NumberAnimation { duration: Style.animationNormal }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton | Qt.ForwardButton | Qt.BackButton
    onEntered: {
      if (!PanelService.getPanel("mediaPlayerPanel", root.screen)?.isPanelOpen)
        TooltipService.show(root, root.label, BarService.getTooltipDirection(root.screenName));
    }
    onExited: TooltipService.hide()
    onClicked: mouse => {
                 TooltipService.hide();
                 if (mouse.button === Qt.LeftButton)
                   PanelService.getPanel("mediaPlayerPanel", root.screen)?.toggle(root);
                 else if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton)
                   MediaService.playPause();
                 else if (mouse.button === Qt.ForwardButton)
                   MediaService.next();
                 else if (mouse.button === Qt.BackButton)
                   MediaService.previous();
               }
  }
}
