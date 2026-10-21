pragma Singleton

import QtQuick
import qs.Commons
import qs.Services.Power

QtObject {
  // Noctalia's own dark mode switch; the night palette comes from the rakko wallpaper.
  readonly property bool dark: Settings.data.colorSchemes.darkMode

  readonly property color paper: dark ? "#1d2130" : "#fcf6e7"
  readonly property color cream: dark ? "#262c40" : "#f5ecd4"
  readonly property color tan: dark ? "#353d56" : "#ebdfc4"
  readonly property color inkFaint: dark ? "#7f86a3" : "#ab9384"
  readonly property color inkSoft: dark ? "#aeb3c9" : "#7e6258"
  readonly property color ink: dark ? "#f4e6cf" : "#4b302b"
  readonly property color pink: dark ? "#f39ab0" : "#e3708b"
  readonly property color honey: dark ? "#f2aa52" : "#e09a2f"
  readonly property color red: dark ? "#ef7a7a" : "#d65a5a"

  readonly property color line: dark ? "#efdfc4" : "#4b302b"
  readonly property color shadow: dark ? "#0a0c14" : "#4b302b"
  readonly property color blush: dark ? "#9c5672" : "#f6b4c1"
  readonly property color grass: dark ? "#3e5a52" : "#c3e2a6"
  readonly property color grassDeep: dark ? "#6f9c6a" : "#8fc56c"
  readonly property color hachiware: dark ? "#8db8dc" : "#79a9d1"
  readonly property color usagi: dark ? "#6b5530" : "#fbe8a8"
  readonly property color white: dark ? "#2a3047" : "#fffdf8"

  readonly property string font: "Maple Mono NF"
  readonly property string display: "Nunito"

  readonly property real backdropBrightness: dark ? -0.06 : 0.04
  readonly property real backdropSaturation: -0.05

  readonly property bool fx: !Settings.data.general.animationDisabled && !PowerProfileService.noctaliaPerformanceMode

  function lit(base, t) {
    return Qt.tint(base, Qt.alpha(pink, Math.max(0, Math.min(1, t))));
  }

  function size(px) {
    return Math.round(px * Style.uiScaleRatio);
  }
}
