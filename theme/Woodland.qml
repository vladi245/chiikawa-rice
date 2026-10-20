pragma Singleton

import QtQuick
import qs.Commons
import qs.Services.Power

// Keeps the woodland token names so the same plugins work with either theme.
QtObject {
  readonly property color night: "#fcf6e7"
  readonly property color dusk: "#f5ecd4"
  readonly property color moss: "#ebdfc4"
  readonly property color bark: "#ab9384"
  readonly property color fog: "#7e6258"
  readonly property color mist: "#4b302b"
  readonly property color windowLight: "#e3708b"
  readonly property color ember: "#e09a2f"
  readonly property color blood: "#d65a5a"

  readonly property color line: "#4b302b"
  readonly property color blush: "#f6b4c1"
  readonly property color grass: "#c3e2a6"
  readonly property color grassDeep: "#8fc56c"
  readonly property color hachiware: "#79a9d1"
  readonly property color usagi: "#fbe8a8"
  readonly property color white: "#fffdf8"

  readonly property string font: "Maple Mono NF"
  readonly property string display: "Nunito"

  readonly property real backdropBrightness: 0.04
  readonly property real backdropSaturation: -0.05

  readonly property bool fx: !Settings.data.general.animationDisabled && !PowerProfileService.noctaliaPerformanceMode

  function lit(base, t) {
    return Qt.tint(base, Qt.alpha(windowLight, Math.max(0, Math.min(1, t))));
  }

  function size(px) {
    return Math.round(px * Style.uiScaleRatio);
  }
}
