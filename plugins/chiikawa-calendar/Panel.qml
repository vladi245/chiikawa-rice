import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.Commons
import qs.Services.Location
import qs.Services.System
import qs.Widgets
import "../../chiikawa"

CPanel {
  id: root

  contentPreferredWidth: Theme.size(400)
  contentPreferredHeight: Theme.size(640)
  scene.density: 22
  scene.pineScale: 0.7
  spacing: Theme.size(14)

  readonly property var now: Time.now
  readonly property var loc: Settings.data.location
  readonly property var weather: loc.weatherEnabled ? (LocationService.data.weather ?? null) : null

  property int year: now.getFullYear()
  property int month: now.getMonth()
  property date chosen: new Date(now.getFullYear(), now.getMonth(), now.getDate())
  property int slideDirection: 0

  Component.onCompleted: loadEvents()

  function loadEvents() {
    if (!loc.showCalendarEvents)
      return;
    const today = new Date();
    const start = new Date(year, month, 1), end = new Date(year, month + 1, 0);
    const behind = Math.max(0, Math.ceil((today - start) / 86400000));
    const ahead = Math.max(0, Math.ceil((end - today) / 86400000));
    CalendarService.loadEvents(ahead + 30, behind + 30);
  }

  function shiftMonth(delta) {
    const d = new Date(year, month + delta, 1);
    slideDirection = delta;
    year = d.getFullYear();
    month = d.getMonth();
    monthSlide.restart();
    loadEvents();
  }
  function goToday() {
    const t = new Date();
    slideDirection = (t.getFullYear() * 12 + t.getMonth()) > (year * 12 + month) ? 1 : -1;
    year = t.getFullYear();
    month = t.getMonth();
    chosen = new Date(t.getFullYear(), t.getMonth(), t.getDate());
    monthSlide.restart();
    loadEvents();
  }

  function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
  }
  readonly property int firstWeekday: loc.firstDayOfWeek >= 0 ? loc.firstDayOfWeek : (I18n.locale.firstDayOfWeek % 7)
  readonly property var days: {
    const first = new Date(year, month, 1);
    const offset = (first.getDay() - firstWeekday + 7) % 7;
    const out = [];
    for (let i = 0; i < 42; i++)
      out.push(new Date(year, month, 1 - offset + i));
    return out;
  }
  function weekNumber(d) {
    const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
    const day = t.getUTCDay() || 7;
    t.setUTCDate(t.getUTCDate() + 4 - day);
    const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
    return Math.ceil(((t - yearStart) / 86400000 + 1) / 7);
  }

  function eventsOn(d) {
    if (!loc.showCalendarEvents || !CalendarService.available)
      return [];
    const start = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime() / 1000;
    const end = start + 86400;
    return (CalendarService.events || []).filter(e => (e.start >= start && e.start < end) || (e.end > start && e.end <= end) || (e.start < start && e.end > end));
  }
  function isAllDay(e) {
    const s = new Date(e.start * 1000);
    return (e.end - e.start) % 86400 === 0 && s.getHours() === 0 && s.getMinutes() === 0;
  }
  function clock(t) {
    return I18n.locale.toString(new Date(t * 1000), loc.use12hourFormat ? "h:mm AP" : "HH:mm");
  }

  function parseLocal(iso) {
    // open-meteo gives local wall time ("2026-10-17T07:58") for the location.
    return iso ? new Date(iso.replace(/-/g, "/").replace("T", " ")) : null;
  }
  readonly property var sunrise: weather ? parseLocal(weather.daily?.sunrise?.[0]) : null
  readonly property var sunset: weather ? parseLocal(weather.daily?.sunset?.[0]) : null
  readonly property bool daytime: sunrise && sunset ? (now >= sunrise && now < sunset) : (now.getHours() >= 7 && now.getHours() < 19)
  readonly property real arcProgress: {
    if (!sunrise || !sunset)
      return daytime ? (now.getHours() - 7) / 12 : 0.5;
    if (daytime)
      return (now - sunrise) / (sunset - sunrise);
    const nightLength = 86400000 - (sunset - sunrise);
    const sinceSunset = now >= sunset ? now - sunset : now - (sunset - 86400000);
    return Math.max(0, Math.min(1, sinceSunset / nightLength));
  }
  function duration(ms) {
    const m = Math.round(ms / 60000);
    return `${Math.floor(m / 60)}h ${String(m % 60).padStart(2, "0")}m`;
  }

  // Moon phase: 0 new, 0.5 full (synodic month from a known new moon).
  readonly property real moonPhase: {
    const synodic = 29.530588853;
    const known = Date.UTC(2000, 0, 6, 18, 14) / 86400000;
    const days = now.getTime() / 86400000 - known;
    return ((days % synodic) + synodic) % synodic / synodic;
  }
  readonly property string moonName: {
    const p = moonPhase;
    if (p < 0.03 || p > 0.97)
      return "new moon";
    if (p < 0.22)
      return "waxing crescent";
    if (p < 0.28)
      return "first quarter";
    if (p < 0.47)
      return "waxing gibbous";
    if (p < 0.53)
      return "full moon";
    if (p < 0.72)
      return "waning gibbous";
    if (p < 0.78)
      return "last quarter";
    return "waning crescent";
  }

  function temperature(c) {
    const t = loc.useFahrenheit ? LocationService.celsiusToFahrenheit(c) : c;
    return Math.round(t) + "°";
  }

  Item {
    width: parent.width
    height: Theme.size(64)

    Row {
      id: timeRow
      spacing: Theme.size(4)
      Text {
        text: I18n.locale.toString(root.now, root.loc.use12hourFormat ? "h:mm" : "HH:mm")
        font.family: Theme.font
        font.pointSize: 32
        font.weight: Font.Light
        color: Theme.pink
      }
      Text {
        anchors.baseline: parent.children[0].baseline
        text: I18n.locale.toString(root.now, ":ss") + (root.loc.use12hourFormat ? I18n.locale.toString(root.now, " AP").toLowerCase() : "")
        font.family: Theme.font
        font.pointSize: 12
        color: Theme.inkFaint
      }
    }
    Column {
      anchors.right: parent.right
      anchors.verticalCenter: timeRow.verticalCenter
      spacing: Theme.size(2)
      Text {
        anchors.right: parent.right
        text: I18n.locale.toString(root.now, "dddd").toLowerCase()
        font.family: Theme.font
        font.pointSize: 11
        color: Theme.ink
      }
      Text {
        anchors.right: parent.right
        text: I18n.locale.toString(root.now, "d MMMM yyyy").toLowerCase() + `  ·  week ${root.weekNumber(root.now)}`
        font.family: Theme.font
        font.pointSize: 8
        color: Theme.inkFaint
      }
    }
  }

  Item {
    id: sky
    width: parent.width
    height: Theme.size(84)

    readonly property real arcLeft: Theme.size(26)
    readonly property real arcWidth: width - arcLeft * 2
    readonly property real arcHeight: Theme.size(46)
    readonly property real horizon: Theme.size(58)
    function point(t) {
      const a = Math.PI * (1 - t);
      return Qt.point(arcLeft + arcWidth / 2 + Math.cos(a) * arcWidth / 2, horizon - Math.sin(a) * arcHeight);
    }

    Rectangle {
      y: sky.horizon
      width: parent.width
      height: 1
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.5; color: Qt.alpha(Theme.inkSoft, 0.35) }
        GradientStop { position: 1.0; color: "transparent" }
      }
    }

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeWidth: 1.2
        strokeColor: Qt.alpha(Theme.inkSoft, 0.25)
        strokeStyle: ShapePath.DashLine
        dashPattern: [2, 4]
        fillColor: "transparent"
        PathSvg {
          path: {
            let d = "";
            for (let i = 0; i <= 48; i++) {
              const p = sky.point(i / 48);
              d += (i === 0 ? "M " : " L ") + p.x.toFixed(1) + " " + p.y.toFixed(1);
            }
            return d;
          }
        }
      }
      ShapePath {
        strokeWidth: 1.6
        strokeColor: Qt.alpha(root.daytime ? Theme.honey : Theme.ink, 0.55)
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathSvg {
          path: {
            const end = Math.max(0.001, root.arcProgress);
            let d = "";
            for (let i = 0; i <= 48; i++) {
              const p = sky.point(end * i / 48);
              d += (i === 0 ? "M " : " L ") + p.x.toFixed(1) + " " + p.y.toFixed(1);
            }
            return d;
          }
        }
      }
    }

    Item {
      id: body
      readonly property point at: sky.point(root.arcProgress)
      width: Theme.size(16)
      height: width
      x: at.x - width / 2
      y: at.y - height / 2

      Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.daytime ? Theme.lit(Theme.honey, 0.55) : Theme.ink
        layer.enabled: Theme.fx
        layer.effect: MultiEffect {
          shadowEnabled: true
          shadowColor: root.daytime ? Theme.honey : Theme.ink
          shadowBlur: 1
          shadowOpacity: root.daytime ? 0.95 : 0.6
          shadowHorizontalOffset: 0
          shadowVerticalOffset: 0
          blurMax: 28
        }
      }
      Rectangle {
        visible: !root.daytime
        width: parent.width
        height: width
        radius: width / 2
        color: "#15160f"
        x: {
          const p = root.moonPhase; // 0 new .. 0.5 full .. 1 new
          return p < 0.5 ? -p * 2 * width : (1 - p) * 2 * width;
        }
        opacity: 0.92
      }
      clip: !root.daytime
    }

    Text {
      x: sky.arcLeft - width / 2
      y: sky.horizon + Theme.size(6)
      text: root.sunrise ? Qt.formatTime(root.sunrise, root.loc.use12hourFormat ? "h:mm" : "HH:mm") : ""
      font.family: Theme.font
      font.pointSize: 7.5
      color: Theme.inkFaint
    }
    Text {
      x: sky.arcLeft + sky.arcWidth - width / 2
      y: sky.horizon + Theme.size(6)
      text: root.sunset ? Qt.formatTime(root.sunset, root.loc.use12hourFormat ? "h:mm" : "HH:mm") : ""
      font.family: Theme.font
      font.pointSize: 7.5
      color: Theme.inkFaint
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      y: sky.horizon + Theme.size(6)
      text: {
        if (!root.sunrise || !root.sunset)
          return root.moonName;
        if (root.daytime)
          return `daylight ${root.duration(root.sunset - root.sunrise)}  ·  sunset in ${root.duration(root.sunset - root.now)}`;
        const nextRise = root.now < root.sunrise ? root.sunrise : new Date(root.sunrise.getTime() + 86400000);
        return `${root.moonName}  ·  sunrise in ${root.duration(nextRise - root.now)}`;
      }
      font.family: Theme.font
      font.pointSize: 8
      color: Theme.inkSoft
    }
  }

  Item {
    width: parent.width
    height: Theme.size(30)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: I18n.locale.toString(new Date(root.year, root.month, 1), "MMMM").toLowerCase()
      font.family: Theme.font
      font.pointSize: 13
      color: Theme.ink
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      x: parent.children[0].implicitWidth + Theme.size(8)
      text: root.year
      font.family: Theme.font
      font.pointSize: 13
      color: Theme.inkFaint
    }
    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Theme.size(6)
      CButton {
        visible: root.year !== root.now.getFullYear() || root.month !== root.now.getMonth() || !root.sameDay(root.chosen, root.now)
        text: "today"
        onClicked: root.goToday()
      }
      CButton {
        icon: "chevron-left"
        onClicked: root.shiftMonth(-1)
      }
      CButton {
        icon: "chevron-right"
        onClicked: root.shiftMonth(1)
      }
    }
  }

  Item {
    id: monthBox
    width: parent.width
    readonly property bool weeks: root.loc.showWeekNumberInCalendar
    readonly property real weekCol: weeks ? Theme.size(26) : 0
    readonly property real cell: (width - weekCol) / 7
    readonly property real rowHeight: Theme.size(38)
    height: Theme.size(20) + rowHeight * 6
    clip: true

    WheelHandler {
      onWheel: event => root.shiftMonth(event.angleDelta.y > 0 ? -1 : 1)
    }

    Repeater {
      model: 7
      delegate: Text {
        required property int index
        readonly property var day: new Date(2024, 0, 7 + ((root.firstWeekday + index) % 7)) // 2024-01-07 is a Sunday
        x: monthBox.weekCol + index * monthBox.cell
        width: monthBox.cell
        horizontalAlignment: Text.AlignHCenter
        text: I18n.locale.toString(day, "ddd").toLowerCase().slice(0, 2)
        font.family: Theme.font
        font.pointSize: 7.5
        color: day.getDay() === 0 || day.getDay() === 6 ? Qt.alpha(Theme.inkFaint, 0.7) : Theme.inkFaint
      }
    }

    Item {
      id: grid
      y: Theme.size(20)
      width: parent.width
      height: monthBox.rowHeight * 6
      transform: Translate {
        id: gridShift
      }

      Repeater {
        model: monthBox.weeks ? 6 : 0
        delegate: Text {
          required property int index
          y: index * monthBox.rowHeight
          width: monthBox.weekCol
          height: monthBox.rowHeight
          verticalAlignment: Text.AlignVCenter
          text: root.weekNumber(root.days[index * 7])
          font.family: Theme.font
          font.pointSize: 7
          color: Qt.alpha(Theme.inkFaint, 0.7)
        }
      }

      Repeater {
        model: root.days
        delegate: Item {
          id: dayCell
          required property var modelData
          required property int index
          readonly property bool inMonth: modelData.getMonth() === root.month
          readonly property bool today: root.sameDay(modelData, root.now)
          readonly property bool chosen: root.sameDay(modelData, root.chosen)
          readonly property var events: root.eventsOn(modelData)
          readonly property bool weekend: modelData.getDay() === 0 || modelData.getDay() === 6
          x: monthBox.weekCol + (index % 7) * monthBox.cell
          y: Math.floor(index / 7) * monthBox.rowHeight
          width: monthBox.cell
          height: monthBox.rowHeight

          Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) - Theme.size(4)
            height: width
            radius: Theme.size(5)
            visible: dayCell.today || dayCell.chosen || cellHover.hovered
            color: dayCell.today ? Qt.alpha(Theme.pink, 0.2) : (cellHover.hovered ? Qt.alpha(Theme.pink, 0.07) : "transparent")
            border.width: 1
            border.color: dayCell.today ? Qt.alpha(Theme.pink, 0.7) : Qt.alpha(Theme.inkSoft, dayCell.chosen ? 0.5 : 0.2)
            layer.enabled: Theme.fx && dayCell.today
            layer.effect: MultiEffect {
              shadowEnabled: true
              shadowColor: Theme.pink
              shadowBlur: 1
              shadowOpacity: 0.5
              shadowHorizontalOffset: 0
              shadowVerticalOffset: 0
              blurMax: 20
            }
          }

          Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: dayCell.events.length ? -Theme.size(3) : 0
            text: dayCell.modelData.getDate()
            font.family: Theme.font
            font.pointSize: 9.5
            font.weight: dayCell.today ? Font.Bold : Font.Normal
            color: dayCell.today ? Theme.pink : (dayCell.weekend ? Theme.inkSoft : Theme.ink)
            opacity: dayCell.inMonth ? 1 : 0.3
          }

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.size(6)
            spacing: 2
            Repeater {
              model: Math.min(3, dayCell.events.length)
              delegate: Rectangle {
                width: 4
                height: 4
                radius: 2
                color: Theme.honey
                opacity: dayCell.inMonth ? 0.9 : 0.4
              }
            }
          }

          HoverHandler {
            id: cellHover
            cursorShape: Qt.PointingHandCursor
          }
          TapHandler {
            onTapped: root.chosen = new Date(dayCell.modelData.getFullYear(), dayCell.modelData.getMonth(), dayCell.modelData.getDate())
            onDoubleTapped: {
              const d = dayCell.modelData;
              if (ProgramCheckerService.gnomeCalendarAvailable)
                Quickshell.execDetached(["gnome-calendar", "--date", `${String(d.getMonth() + 1).padStart(2, "0")}/${String(d.getDate()).padStart(2, "0")}/${String(d.getFullYear()).slice(2)}`]);
            }
          }
        }
      }
    }

    ParallelAnimation {
      id: monthSlide
      NumberAnimation { target: gridShift; property: "x"; from: root.slideDirection * Theme.size(40); to: 0; duration: Theme.fx ? 320 : 0; easing.type: Easing.OutCubic }
      NumberAnimation { target: grid; property: "opacity"; from: 0; to: 1; duration: Theme.fx ? 260 : 0 }
    }
  }

  Column {
    width: parent.width
    spacing: Theme.size(2)
    visible: root.loc.showCalendarEvents

    readonly property var events: root.eventsOn(root.chosen)

    Text {
      text: (root.sameDay(root.chosen, root.now) ? "today" : I18n.locale.toString(root.chosen, "dddd d MMMM").toLowerCase()) + (parent.events.length ? `  ·  ${parent.events.length} ${parent.events.length === 1 ? "plan" : "plans"}` : "")
      font.family: Theme.font
      font.pointSize: 8
      color: Theme.inkFaint
      bottomPadding: Theme.size(4)
    }

    Repeater {
      model: parent.events.slice(0, 4)
      delegate: CRow {
        required property var modelData
        icon: root.isAllDay(modelData) ? "calendar" : "clock"
        title: modelData.summary || "event"
        detail: root.isAllDay(modelData) ? "all day" : `${root.clock(modelData.start)} – ${root.clock(modelData.end)}`
        subtitle: modelData.location || modelData.calendar || ""
        active: !root.isAllDay(modelData) && root.now.getTime() / 1000 >= modelData.start && root.now.getTime() / 1000 < modelData.end
        implicitHeight: Theme.size(40)
        interactive: false
      }
    }

    Text {
      visible: parent.events.length === 0
      leftPadding: Theme.size(4)
      text: CalendarService.available ? "nothing planned · a quiet day" : "no calendar connected"
      font.family: Theme.font
      font.italic: true
      font.pointSize: 8.5
      color: Qt.alpha(Theme.inkSoft, 0.6)
    }
  }

  Row {
    visible: root.weather !== null
    width: parent.width
    spacing: Theme.size(12)

    Column {
      width: Theme.size(120)
      spacing: Theme.size(2)
      Row {
        spacing: Theme.size(8)
        NIcon {
          anchors.verticalCenter: parent.verticalCenter
          icon: root.weather ? LocationService.weatherSymbolFromCode(root.weather.current_weather.weathercode) : "cloud"
          pointSize: 18
          color: Theme.ink
        }
        Text {
          text: root.weather ? root.temperature(root.weather.current_weather.temperature) : ""
          font.family: Theme.font
          font.pointSize: 18
          color: Theme.pink
        }
      }
      Text {
        width: parent.width
        elide: Text.ElideRight
        text: root.weather ? LocationService.weatherDescriptionFromCode(root.weather.current_weather.weathercode).toLowerCase() : ""
        font.family: Theme.font
        font.pointSize: 8
        color: Theme.inkSoft
      }
      Text {
        visible: !root.loc.hideWeatherCityName
        text: (root.loc.name || "").split(",")[0].toLowerCase()
        font.family: Theme.font
        font.pointSize: 7.5
        color: Theme.inkFaint
      }
    }

    Row {
      spacing: Theme.size(4)
      Repeater {
        model: root.weather ? Math.min(4, (root.weather.daily?.time?.length ?? 1) - 1) : 0
        delegate: Column {
          required property int index
          readonly property int day: index + 1
          width: Theme.size(56)
          spacing: Theme.size(3)
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.locale.toString(root.parseLocal(root.weather.daily.time[parent.day] + "T12:00"), "ddd").toLowerCase()
            font.family: Theme.font
            font.pointSize: 7.5
            color: Theme.inkFaint
          }
          NIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: LocationService.weatherSymbolFromCode(root.weather.daily.weathercode[parent.day])
            pointSize: 12
            color: Theme.inkSoft
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.temperature(root.weather.daily.temperature_2m_max[parent.day]).replace("°", "") + "/" + root.temperature(root.weather.daily.temperature_2m_min[parent.day])
            font.family: Theme.font
            font.pointSize: 7.5
            color: Theme.ink
          }
        }
      }
    }
  }
}
