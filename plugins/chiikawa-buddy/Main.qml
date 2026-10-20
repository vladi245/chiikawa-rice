import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Services.Compositor
import qs.Services.Hardware
import qs.Services.Media
import qs.Services.System
import "../../chiikawa"

Item {
  id: root
  property var pluginApi: null

  CastFile {
    id: castFile
  }

  readonly property string homeScreen: {
    const wanted = pluginApi?.pluginSettings?.screen || "";
    const screens = Quickshell.screens;
    if (wanted && screens.some(s => s.name === wanted))
      return wanted;
    const external = screens.find(s => !s.name.startsWith("eDP"));
    return (external || screens[0])?.name || "";
  }

  readonly property string registrationId: "plugin:chiikawa-buddy"
  Component.onCompleted: SystemStatService.registerComponent(registrationId)
  Component.onDestruction: SystemStatService.unregisterComponent(registrationId)

  Variants {
    model: castFile.who("pet") !== "none" ? Quickshell.screens.filter(s => s.name === root.homeScreen) : []

    delegate: PanelWindow {
      id: win
      required property ShellScreen modelData
      screen: modelData

      color: "transparent"
      anchors.top: true
      anchors.bottom: true
      anchors.left: true
      anchors.right: true
      visible: !CompositorService.overviewActive
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "chiikawa-pet"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: Region {
        item: petItem.hitItem
      }

      Pet {
        id: petItem
        anchors.fill: parent
        pluginApi: root.pluginApi
        cast: castFile
      }
    }
  }

  component Pet: Item {
    id: pet
    property var pluginApi: null
    property var cast: null
    property alias hitItem: hit

    readonly property real size: Theme.size(84)
    readonly property real ground: height - Theme.size(6)

    readonly property string friend: cast?.who("pet") ?? "hachiware"
    readonly property var friends: cast?.kinds ?? ["hachiware"]
    readonly property var catchphrases: ({
                                           "chiikawa": ["わっ…!", "ウンッ", "ワァ…", "フ…"],
                                           "hachiware": ["なんとかなれーッ!", "えへへ", "ﾌﾌ…", "わーい!"],
                                           "usagi": ["ヤハ!", "ウラ!", "プルルルル…", "ハァ?"],
                                           "momonga": ["かわいいでしょ?", "フフン", "よしよしして!", "ﾌﾟｲｯ"]
                                         })

    readonly property bool playing: MediaService.currentPlayer !== null && MediaService.isPlaying
    readonly property var battery: BatteryService.primaryDevice
    readonly property bool sweaty: mind.hot

    Mind {
      id: mind
      pluginApi: pet.pluginApi
    }
    property real actionUntil: 0

    property real px: width * 0.7
    property real lift: 0
    property int dir: -1
    property string action: "idle"     // idle | walk | run | rest | sleep | dance | happy | cry
    property bool stay: pluginApi?.pluginSettings?.stay ?? false
    property bool held: false
    property bool falling: false
    property bool petted: false
    property bool loving: false
    property string phrase: ""
    property string idleRole: "idle"

    function has(role) {
      return cast?.has(friend, role) ?? false;
    }
    readonly property bool canWalk: has("walk") || has("run")
    readonly property string role: held || falling ? "" : loving ? "love" : petted ? "happy" : action === "walk" ? (has("walk") ? "walk" : "run") : action === "run" ? (has("run") ? "run" : "walk") : action === "rest" || action === "sleep" ? "rest" : action === "dance" || action === "happy" || action === "cry" ? action : idleRole

    readonly property bool hovered: area.containsMouse
    readonly property bool busy: held || falling || hop.running
    readonly property string mood: held || falling ? "wow" : petted ? "happy" : action === "sleep" ? "sleep" : action === "cry" ? "cry" : action === "dance" || action === "happy" ? "happy" : "idle"

    function say(text, ms) {
      phrase = text;
      phraseTimer.interval = ms || 2200;
      phraseTimer.restart();
    }

    function petIt() {
      mind.petted();
      if (action === "sleep")
        say("ん…おはよ", 1400);
      petted = true;
      pettedTimer.restart();
      face.boing();
      if (action === "sleep")
        action = "idle";
      const lines = catchphrases[friend] || ["♥"];
      say(lines[Math.floor(Math.random() * lines.length)]);
      hearts.burst();
    }

    function save(key, value) {
      if (!pluginApi)
        return;
      pluginApi.pluginSettings[key] = value;
      pluginApi.saveSettings();
    }

    function nextFriend() {
      const next = friends[(friends.indexOf(friend) + 1) % friends.length];
      cast?.set("pet", next);
      face.boing();
      say((cast?.names[next] ?? next) + "!", 1400);
    }

    function love() {
      mind.loved();
      loving = true;
      lovingTimer.restart();
      face.boing();
      hearts.burst();
    }

    function toggleStay() {
      stay = !stay;
      save("stay", stay);
      walkAnim.stop();
      action = stay ? "rest" : "idle";
      actionUntil = Date.now() + 20000;
      say(stay ? "I'll stay here!" : "let's go~", 1600);
    }

    function think() {
      if (busy || hovered)
        return;
      if (action === "walk" || action === "run") {
        if (walkAnim.running)
          return;
      } else if (Date.now() < actionUntil) {
        return;
      }
      let next = mind.choose({ "walk": has("walk") && !stay, "run": has("run") && !stay });
      if (next === "cry" && !has("cry"))
        next = has("rest") ? "rest" : "idle";
      if ((next === "happy" && !has("happy")) || (next === "dance" && !has("dance")))
        next = "idle";
      if (next === "sleep" && action !== "sleep")
        say("ふぁ…おやすみ", 1800);
      else if (action === "sleep" && next !== "sleep")
        say("おはよ!", 1400);
      if (next === "idle") {
        const idles = cast?.idles(friend) ?? ["idle"];
        idleRole = idles[Math.floor(Math.random() * idles.length)] || "idle";
      }
      if (next === "walk" || next === "run") {
        walkSomewhere(next === "run");
        return;
      }
      action = next;
      actionUntil = Date.now() + mind.duration(next);
    }

    Connections {
      target: mind
      function onReact(kind, line) {
        if (pet.held)
          return;
        if (kind === "welcome") {
          walkAnim.stop();
          pet.action = "idle";
          pet.actionUntil = Date.now() + 6000;
          pet.say(line, 2600);
          if (pet.has("love"))
            pet.love();
          else
            hop.restart();
        } else if (kind === "notified") {
          if (pet.action !== "sleep") {
            pet.say(line, 900);
            face.boing();
          }
        } else if (pet.action !== "sleep" || kind === "fed") {
          pet.say(line, 1600);
        }
      }
    }

    function walkSomewhere(running) {
      const margin = size;
      let target = px;
      for (let i = 0; i < 6 && Math.abs(target - px) < size * 1.5; i++)
        target = margin + Math.random() * (width - margin * 2);
      if (!canWalk)
        return;
      const fast = running || !has("walk");
      const speed = Theme.size(fast ? 95 : 38);
      dir = target > px ? 1 : -1;
      action = fast && has("run") ? "run" : "walk";
      walkAnim.to = target;
      walkAnim.duration = Math.abs(target - px) / speed * 1000;
      walkAnim.restart();
    }

    Timer {
      running: pet.visible
      repeat: true
      interval: 5000
      onTriggered: {
        mind.tick(5, pet.action);
        pet.think();
      }
    }

    Timer {
      id: feelTimer
      interval: 600
      onTriggered: pet.say((pet.cast?.names[pet.friend] ?? pet.friend) + ": " + mind.feeling, 4000)
    }
    onHoveredChanged: if (hovered && !held)
                        feelTimer.restart()
                      else
                        feelTimer.stop()
    Timer {
      id: pettedTimer
      interval: 1800
      onTriggered: pet.petted = false
    }
    Timer {
      id: lovingTimer
      interval: 2600
      onTriggered: pet.loving = false
    }
    Timer {
      id: phraseTimer
      onTriggered: pet.phrase = ""
    }

    // Only move while a walk/run animation is showing, so it never slides.
    NumberAnimation {
      id: walkAnim
      target: pet
      property: "px"
      easing.type: Easing.Linear
      paused: running && !(face.playingGif && (face.variant === "walk" || face.variant === "run"))
      onFinished: if (pet.action === "walk" || pet.action === "run") {
                    pet.action = "idle";
                    pet.actionUntil = Date.now() + 3000;
                  }
    }

    NumberAnimation {
      id: fall
      target: pet
      property: "lift"
      to: 0
      easing.type: Easing.OutBounce
      onStarted: pet.falling = true
      onFinished: {
        pet.falling = false;
        face.boing();
        pet.say(pet.friend === "usagi" ? "ヤハ!" : "ふぅ…", 1400);
      }
    }

    SequentialAnimation {
      id: hop
      NumberAnimation { target: pet; property: "lift"; to: pet.size * 0.9; duration: 260; easing.type: Easing.OutQuad }
      NumberAnimation { target: pet; property: "lift"; to: 0; duration: 520; easing.type: Easing.OutBounce }
      ScriptAction { script: face.boing() }
    }

    Timer {
      running: pet.action === "dance" && !pet.busy && Theme.fx
      repeat: true
      interval: 1700
      onTriggered: if (Math.random() < 0.5)
                     hop.restart()
    }

    Rectangle {
      readonly property real s: Math.max(0.35, 1 - pet.lift / (pet.height * 0.6))
      width: pet.size * 0.7 * s
      height: width * 0.22
      radius: height / 2
      x: pet.px - width / 2
      y: pet.ground - height / 2
      color: Qt.alpha(Theme.line, 0.18 * s)
    }

    Item {
      id: hit
      width: pet.size
      height: pet.size
      x: pet.px - width / 2
      y: pet.ground - height - pet.lift
      rotation: pet.held ? Math.max(-14, Math.min(14, area.swing)) : (pet.action === "walk" && !face.playingGif ? pet.dir * 4 : 0)
      Behavior on rotation {
        SpringAnimation { spring: 4; damping: 0.3; epsilon: 0.2 }
      }

      Item {
        anchors.fill: parent
        transform: Scale {
          origin.x: pet.size / 2
          origin.y: pet.size
          yScale: !face.playingGif && (pet.action === "rest" || pet.action === "sleep") ? 0.96 : 1
          xScale: !face.playingGif && (pet.action === "rest" || pet.action === "sleep") ? 1.02 : 1
          Behavior on yScale {
            SpringAnimation { spring: 4; damping: 0.35; epsilon: 0.005 }
          }
          Behavior on xScale {
            SpringAnimation { spring: 4; damping: 0.35; epsilon: 0.005 }
          }
        }

        Friend {
          id: face
          anchors.fill: parent
          kind: pet.friend
          role: pet.role
          mood: pet.mood
          walking: pet.action === "walk" && !pet.busy
          bobbing: pet.action === "dance" && !pet.busy
          animated: Theme.fx
        }
      }

      Rectangle {
        visible: pet.sweaty && !pet.petted
        width: pet.size * 0.1
        height: width * 1.4
        radius: width / 2
        color: Theme.hachiware
        border.width: 1
        border.color: Theme.line
        x: pet.size * 0.82
        y: pet.size * 0.22
        SequentialAnimation on opacity {
          running: Theme.fx && pet.sweaty
          loops: Animation.Infinite
          NumberAnimation { from: 1; to: 0.3; duration: 600 }
          NumberAnimation { from: 0.3; to: 1; duration: 600 }
        }
      }

      Text {
        visible: (pet.action === "dance" || pet.action === "sleep") && !pet.busy
        x: pet.size * 0.86
        y: -pet.size * 0.05
        text: pet.action === "dance" ? "♪" : "z"
        font.family: Theme.display
        font.pixelSize: pet.size * 0.26
        font.weight: Font.Black
        color: pet.action === "dance" ? Theme.pink : Theme.hachiware
        SequentialAnimation on y {
          running: Theme.fx && parent.visible
          loops: Animation.Infinite
          NumberAnimation { from: pet.size * 0.05; to: -pet.size * 0.2; duration: 1200; easing.type: Easing.OutQuad }
        }
        SequentialAnimation on opacity {
          running: Theme.fx && parent.visible
          loops: Animation.Infinite
          NumberAnimation { from: 0; to: 1; duration: 300 }
          NumberAnimation { to: 0; duration: 900 }
        }
      }

      Item {
        id: hearts
        anchors.fill: parent
        function burst() {
          for (let i = 0; i < heartRepeater.count; i++)
            heartRepeater.itemAt(i).pop();
        }
        Repeater {
          id: heartRepeater
          model: 4
          delegate: Text {
            id: heart
            required property int index
            text: "♥"
            color: index % 2 ? Theme.pink : Theme.blush
            font.pixelSize: pet.size * 0.22
            x: pet.size * (0.15 + index * 0.22)
            y: pet.size * 0.2
            opacity: 0
            function pop() {
              if (Theme.fx)
                anim.restart();
            }
            SequentialAnimation {
              id: anim
              PauseAnimation { duration: heart.index * 80 }
              ParallelAnimation {
                NumberAnimation { target: heart; property: "opacity"; from: 1; to: 0; duration: 1100; easing.type: Easing.InQuad }
                NumberAnimation { target: heart; property: "y"; from: pet.size * 0.2; to: -pet.size * 0.45; duration: 1100; easing.type: Easing.OutCubic }
                NumberAnimation { target: heart; property: "scale"; from: 0.4; to: 1.3; duration: 450; easing.type: Easing.OutBack }
              }
            }
          }
        }
      }

      MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: pet.held ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        property point grab
        property bool dragged: false
        property real swing: 0
        property real lastX: 0

        onPressed: mouse => {
                     if (mouse.button !== Qt.LeftButton)
                       return;
                     grab = Qt.point(mouse.x, mouse.y);
                     dragged = false;
                   }
        onPositionChanged: mouse => {
                             if (!(mouse.buttons & Qt.LeftButton))
                               return;
                             const p = mapToItem(pet, mouse.x, mouse.y);
                             if (!dragged && Math.hypot(mouse.x - grab.x, mouse.y - grab.y) < 6)
                               return;
                             if (!dragged) {
                               dragged = true;
                               walkAnim.stop();
                               fall.stop();
                               hop.stop();
                               pet.falling = false;
                               pet.held = true;
                               mind.handled();
                               pet.action = "idle";
                               pet.say(pet.friend === "chiikawa" ? "わっ…!" : "わーっ!", 1200);
                               lastX = p.x;
                             }
                             swing = (p.x - lastX) * 1.5;
                             lastX = p.x;
                             pet.px = Math.max(pet.size / 2, Math.min(pet.width - pet.size / 2, p.x - grab.x + pet.size / 2));
                             pet.lift = Math.max(0, Math.min(pet.ground - pet.size, pet.ground - p.y - (pet.size - grab.y)));
                           }
        onReleased: mouse => {
                      if (!pet.held)
                        return;
                      pet.held = false;
                      swing = 0;
                      if (pet.lift > 1) {
                        fall.duration = 300 + Math.sqrt(pet.lift) * 38;
                        fall.restart();
                      }
                    }
        onClicked: mouse => {
                     if (dragged)
                       return;
                     if (mouse.button === Qt.RightButton)
                       pet.nextFriend();
                     else if (mouse.button === Qt.MiddleButton)
                       pet.toggleStay();
                     else
                       pet.petIt();
                   }
        onDoubleClicked: mouse => {
                           if (mouse.button === Qt.LeftButton && !pet.busy) {
                             walkAnim.stop();
                             if (pet.action === "walk" || pet.action === "run")
                               pet.action = "idle";
                             if (pet.has("love"))
                               pet.love();
                             else
                               hop.restart();
                           }
                         }
        onContainsMouseChanged: if (containsMouse && (pet.action === "walk" || pet.action === "run")) {
                                  walkAnim.stop();
                                  pet.action = "idle";
                                }
      }
    }

    Rectangle {
      visible: pet.phrase !== ""
      width: words.implicitWidth + Theme.size(20)
      height: words.implicitHeight + Theme.size(10)
      radius: height / 2
      x: Math.max(4, Math.min(pet.width - width - 4, pet.px - width / 2))
      y: hit.y - height - Theme.size(8)
      color: Theme.white
      border.width: 1.5
      border.color: Theme.line
      scale: visible ? 1 : 0.5
      Behavior on scale {
        NumberAnimation { duration: 220; easing.type: Easing.OutBack }
      }
      Text {
        id: words
        anchors.centerIn: parent
        text: pet.phrase
        font.family: Theme.display
        font.pixelSize: Theme.size(13)
        font.weight: Font.Black
        color: Theme.line
      }
    }
  }
}
