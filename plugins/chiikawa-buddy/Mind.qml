import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services.Compositor
import qs.Services.Hardware
import qs.Services.Media
import qs.Services.System

Item {
  id: mind

  property var pluginApi: null

  property real energy: 80
  property real affection: 60
  property real fun: 40
  property real stress: 0
  property real boredom: 30

  readonly property bool playing: MediaService.currentPlayer !== null && MediaService.isPlaying
  readonly property bool charging: BatteryService.batteryCharging
  readonly property bool batteryLow: BatteryService.batteryReady && !charging && (BatteryService.isLowBattery(BatteryService.primaryDevice) || BatteryService.isCriticalBattery(BatteryService.primaryDevice))
  readonly property bool batteryCritical: BatteryService.batteryReady && !charging && BatteryService.isCriticalBattery(BatteryService.primaryDevice)
  readonly property bool hot: SystemStatService.cpuCritical || SystemStatService.tempCritical
  readonly property real load: Math.max(SystemStatService.cpuUsage || 0, ((SystemStatService.cpuTemp || 0) - 40) * 1.6)
  readonly property int hour: Time.now.getHours()
  readonly property bool night: hour >= 23 || hour < 6
  readonly property bool evening: hour >= 21 || hour < 7
  readonly property bool away: awayMonitor.isIdle
  readonly property bool longAway: longAwayMonitor.isIdle
  property int unread: 0

  signal react(string kind, string line)

  function clamp(v) {
    return Math.max(0, Math.min(100, v));
  }

  function tick(seconds, action) {
    const m = seconds / 60;
    const busy = action === "walk" || action === "run" || action === "dance";
    let drain = busy ? 2.2 : 0.8;
    if (evening)
      drain *= 1.6;
    if (action === "sleep")
      energy = clamp(energy + 6 * m);
    else if (action === "rest")
      energy = clamp(energy + 2.5 * m);
    else
      energy = clamp(energy - drain * m);

    affection = clamp(affection - (longAway ? 1.5 : 0.4) * m);
    fun = clamp(fun + (playing ? 4 : -1.2) * m + (action === "dance" ? 2 * m : 0));
    boredom = clamp(boredom + (action === "walk" || action === "run" ? -12 : (away ? 0.5 : 2.5)) * m);

    let target = Math.max(0, load - 55) * 1.6;
    if (batteryCritical)
      target = Math.max(target, 90);
    else if (batteryLow)
      target = Math.max(target, 55);
    target = Math.min(100, target + Math.min(25, unread * 3));
    stress = clamp(stress + (target - stress) * (target > stress ? 0.5 : 0.12) * Math.min(1, m * 4));
  }

  function choose(can) {
    const jitter = () => (Math.random() - 0.5) * 14;
    const s = {};
    s.idle = 28 + jitter();
    s.rest = (65 - energy) * 1.1 + (away ? 18 : 0) + (night ? 10 : 0) + jitter();
    s.sleep = energy < 40 || (night && away) ? (100 - energy) * 1.3 + (night ? 30 : 0) + (away ? 25 : 0) - stress * 0.4 + jitter() : -1;
    s.walk = can.walk && energy > 22 && !away ? boredom * 0.9 + (energy - 40) * 0.25 + jitter() : -1;
    s.run = can.run && stress > 55 && energy > 30 ? stress * 0.8 + jitter() : -1;
    s.dance = playing && energy > 25 ? 40 + fun * 0.7 + jitter() : -1;
    s.happy = affection > 72 && !away ? (affection - 55) + jitter() : -1;
    s.cry = stress > 72 ? stress * 0.9 + jitter() : -1;
    let best = "idle";
    for (const k in s)
      if (s[k] > s[best])
        best = k;
    return best;
  }

  function duration(action) {
    const r = (lo, hi) => (lo + Math.random() * (hi - lo)) * 1000;
    switch (action) {
    case "sleep":
      return r(60, 120);
    case "rest":
      return r(20, 50);
    case "dance":
      return r(15, 35);
    case "happy":
      return r(4, 7);
    case "cry":
      return r(6, 10);
    default:
      return r(6, 16);
    }
  }

  readonly property string feeling: {
    const bits = [];
    if (batteryCritical)
      bits.push("starving (battery)");
    else if (hot)
      bits.push("overheating");
    else if (stress > 60)
      bits.push("stressed" + (unread > 4 ? " (" + unread + " unread)" : load > 70 ? " (busy CPU)" : ""));
    if (energy < 30)
      bits.push(night ? "sleepy, it's late" : "tired");
    else if (energy > 80)
      bits.push("full of energy");
    if (affection > 75)
      bits.push("loved");
    else if (affection < 25)
      bits.push(longAway ? "lonely" : "wants pets");
    if (playing && fun > 50)
      bits.push("vibing");
    if (boredom > 70 && !playing)
      bits.push("bored");
    return bits.length ? bits.join(" · ") : "content";
  }

  function petted() {
    affection = clamp(affection + 14);
    boredom = clamp(boredom - 10);
    stress = clamp(stress - 6);
  }
  function loved() {
    affection = clamp(affection + 22);
    fun = clamp(fun + 10);
  }
  function handled() {
    fun = clamp(fun + 4);
    stress = clamp(stress + 4);
  }

  IdleMonitor {
    id: awayMonitor
    timeout: 180
    respectInhibitors: true
    property real since: 0
    onIsIdleChanged: {
      if (isIdle) {
        since = Date.now();
      } else if (since > 0) {
        const minutes = (Date.now() - since) / 60000;
        if (minutes > 10) {
          mind.affection = mind.clamp(mind.affection + 10);
          mind.react("welcome", minutes > 120 ? "おかえり!! ずっと待ってた…" : "おかえり!");
        }
        since = 0;
      }
    }
  }
  IdleMonitor {
    id: longAwayMonitor
    timeout: 1200
    respectInhibitors: true
  }

  function recount() {
    const model = NotificationService.historyModel;
    const seen = NotificationService.lastSeenTs || 0;
    let fresh = 0;
    for (let i = 0; i < model.count; i++) {
      const ts = model.get(i)?.timestamp;
      if ((ts instanceof Date ? ts.getTime() : ts) > seen)
        fresh++;
    }
    if (fresh > unread)
      react("notified", "!");
    unread = fresh;
  }
  Connections {
    target: NotificationService.historyModel
    function onCountChanged() {
      mind.recount();
    }
  }
  Connections {
    target: NotificationService
    function onLastSeenTsChanged() {
      mind.recount();
    }
  }
  Connections {
    target: CompositorService
    function onWorkspaceChanged() {
      mind.boredom = mind.clamp(mind.boredom + 6);
    }
    function onActiveWindowChanged() {
      mind.boredom = mind.clamp(mind.boredom + 2);
    }
  }
  onPlayingChanged: if (playing) {
                      fun = clamp(fun + 15);
                      react("music", "♪");
                    }
  onChargingChanged: if (charging && BatteryService.batteryReady) {
                       stress = clamp(stress - 20);
                       react("fed", "ごはん!");
                     }
  onHotChanged: if (hot)
                  react("hot", "あつい…")

  function save() {
    if (!pluginApi)
      return;
    pluginApi.pluginSettings.mind = {
      "energy": Math.round(energy),
      "affection": Math.round(affection),
      "fun": Math.round(fun),
      "boredom": Math.round(boredom),
      "savedAt": Date.now()
    };
    pluginApi.saveSettings();
  }

  function restore() {
    const m = pluginApi?.pluginSettings?.mind;
    if (!m)
      return;
    const hours = (Date.now() - (m.savedAt || Date.now())) / 3600000;
    energy = clamp((m.energy ?? 80) + hours * 30);
    affection = clamp((m.affection ?? 60) - hours * 4);
    fun = clamp((m.fun ?? 40) - hours * 10);
    boredom = clamp(m.boredom ?? 30);
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: mind.save()
  }
  // Saved on the timer only: touching plugin settings while the shell tears
  // down (Noctalia restarts, rice switches) is asking for a crash on exit.
  Component.onCompleted: restore()
}
