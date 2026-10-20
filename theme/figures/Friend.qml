import QtQuick
import "cast.js" as Cast

Item {
  id: friend

  property string kind: "hachiware"
  property string role: "idle"
  property string mood: "idle"
  property bool animated: true
  property bool walking: false
  property bool bobbing: false
  property string headgear: "none"
  property color gearColor: "#f2a0b4"

  readonly property var moodRoles: ({ "happy": "happy", "cry": "cry", "sleep": "rest" })
  readonly property string shownRole: role !== "" ? role : (moodRoles[mood] ?? "")
  property string variant: ""
  function pickVariant() {
    const v = shownRole !== "" ? Cast.variants(kind, shownRole) : [];
    variant = v.length ? v[Math.floor(Math.random() * v.length)] : "";
  }
  onShownRoleChanged: pickVariant()
  onKindChanged: pickVariant()
  Component.onCompleted: pickVariant()
  readonly property bool playingGif: variant !== ""
  property alias still: still

  function boing() {
    if (!animated)
      return;
    if (playingGif)
      squish.restart();
    else
      still.boing();
  }

  implicitWidth: 64
  implicitHeight: width

  transform: Scale {
    id: squash
    origin.x: friend.width / 2
    origin.y: friend.height
  }
  SequentialAnimation {
    id: squish
    ParallelAnimation {
      NumberAnimation { target: squash; property: "xScale"; to: 1.1; duration: 90 }
      NumberAnimation { target: squash; property: "yScale"; to: 0.88; duration: 90 }
    }
    ParallelAnimation {
      SpringAnimation { target: squash; property: "xScale"; to: 1; spring: 7; damping: 0.22; epsilon: 0.005 }
      SpringAnimation { target: squash; property: "yScale"; to: 1; spring: 7; damping: 0.22; epsilon: 0.005 }
    }
  }

  AnimatedImage {
    anchors.fill: parent
    visible: friend.playingGif
    source: friend.playingGif ? Qt.resolvedUrl("art/" + friend.kind + "/" + friend.variant + ".gif") : ""
    playing: visible && friend.animated
    fillMode: Image.PreserveAspectFit
    smooth: true
    onSourceChanged: currentFrame = 0
  }

  Mochi {
    id: still
    anchors.fill: parent
    visible: !friend.playingGif
    kind: friend.kind
    mood: friend.mood
    animated: friend.animated
    walking: friend.walking
    bobbing: friend.bobbing
    headgear: friend.headgear
    gearColor: friend.gearColor
  }
}
