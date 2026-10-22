import QtQuick
import qs.Commons
import qs.Ui

// Per-monitor scale rows for the display panel's front page (design/
// per-monitor-scale-spec.md). Each output gets its own slider over the
// daemon's clean scale stops for its current mode — capped at 2.5x per the
// owner's ruling, with the current value always kept so a CLI-set scale
// still reads back. Applies ride hyprmoncfg's draft pipeline
// (edit_profile round-trips, then one applyDraft → the daemon's 10-second
// confirm-revert overlay). Right-click a slider to set that row's committed
// scale on every enabled display.
//
// Spec deviations, agreed at implementation: the Display tab has no keyboard
// cursor chain today (BRIGHTNESS/TEXT SIZE are mouse/wheel only), so the
// h/l row-stepping story is dropped for parity; name/value column widths use
// real pixel budgets through Style.space() instead of the spec's unit slips.
Column {
  id: root

  property var bar: null
  property var profile: null          // current draftProfile from Panel
  property var editorDisplays: []     // editorDocument.displays (metadata + numbers)
  property color foreground: Color.foreground
  property color dim: Qt.darker(foreground, 1.5)
  property color accent: Color.accent
  property string fontFamily: Style.font.family
  property bool editPending: false
  property bool previewBusy: false    // a draft apply/preview is in flight
  property string errorText: ""       // Panel.lastError — reconnect hint etc.

  signal requested(var fieldsByKey)   // { output_key: { scale: 1.2 }, ... }

  spacing: Style.space(5)

  readonly property bool busy: editPending || previewBusy
  readonly property bool blocked: busy || errorText !== ""

  // Pending readout while a drag/wheel gesture is in flight: key + "1.2x".
  property string pendingKey: ""
  property string pendingValue: ""
  // true when the last moved() came from a mouse drag (PanelSlider.dragging).
  // Mouse release applies immediately; wheel stepping debounces below.
  property bool dragSeen: false
  property string wheelKey: ""
  property string wheelRaw: ""

  // Wheel steps fire released() per notch; serialize into one delayed apply
  // instead of hammering the edit_profile round-trip (whose editPending
  // guard would silently drop everything after the first notch).
  Timer {
    id: wheelDebounce
    interval: 600
    repeat: false
    onTriggered: {
      if (root.wheelKey !== "") root.applyOne(root.wheelKey, root.wheelRaw)
      root.clearPending()
    }
  }

  function clearPending() {
    pendingKey = ""
    pendingValue = ""
    wheelKey = ""
    wheelRaw = ""
    dragSeen = false
  }

  // ---- stops (logic lives in Model.js — node-tested) -----------------------

  // Daemon clean-divisor stops for one output, ≤ 2.5, current always kept.
  function stopsFor(output) {
    return Model.cappedScaleStops(editorDisplays, String(output.key || ""), output.scale)
  }

  function stopIndexFor(stops, current) {
    return Model.nearestStopIndex(stops, current)
  }

  function rows() {
    var outputs = profile && profile.outputs instanceof Array ? profile.outputs : []
    var numbers = Model.displayNumberMap(editorDisplays)
    var enabled = []
    var off = []
    for (var i = 0; i < outputs.length; i++) {
      var o = outputs[i] || {}
      var key = String(o.key || "")
      if (key === "") continue
      var stops = stopsFor(o)
      var name = String(Model.outputName(profile, key) || key)
      var row = {
        key: key,
        name: name,
        scale: String(Model.formatScale(o.scale)),
        off: o.enabled === false,
        number: numbers[key] || 0,
        hasStops: stops.length > 0,
        stops: stops,
        stopIndex: stopIndexFor(stops, o.scale)
      }
      if (row.off) off.push(row)
      else enabled.push(row)
    }
    return enabled.concat(off)
  }

  // ---- header summary ------------------------------------------------------

  function enabledRows() {
    var outputs = profile && profile.outputs instanceof Array ? profile.outputs : []
    var list = []
    for (var i = 0; i < outputs.length; i++) {
      var o = outputs[i]
      if (o && o.enabled !== false) list.push(o)
    }
    return list
  }

  function sharedScale() {
    var list = enabledRows()
    if (list.length === 0) return ""
    var shared = ""
    for (var i = 0; i < list.length; i++) {
      var s = String(Model.formatScale(list[i].scale))
      if (s === "" || Number(s) <= 0) return ""
      if (shared === "") shared = s
      else if (shared !== s) return ""
    }
    return shared
  }

  function headerValue() {
    if (busy) return "…"
    var s = sharedScale()
    return s === "" ? "Mixed" : fmtReadout(s) + "x"
  }

  function captionText() {
    if (errorText !== "") return errorText
    if (enabledRows().length <= 1) return "Clean scale steps for this display's current mode"
    return "Per display · right-click a slider to set every display"
  }

  // "2", "1.2", "1.33" — 2 decimals, trailing zeros trimmed (Model-tested).
  function fmtReadout(value) {
    return Model.readoutScale(value)
  }

  // ---- apply emitters (draft pipeline; Panel serializes) --------------------

  function applyOne(key, raw) {
    if (blocked || key === "" || !isFinite(parseFloat(raw))) return
    var fields = {}
    fields[key] = { output_key: key, scale: parseFloat(raw) }
    root.requested(fields)
  }

  function applyAll(raw) {
    if (blocked || !isFinite(parseFloat(raw))) return
    var fields = {}
    var outputs = profile && profile.outputs instanceof Array ? profile.outputs : []
    for (var i = 0; i < outputs.length; i++) {
      var o = outputs[i]
      if (!o || o.enabled === false) continue
      fields[String(o.key)] = { output_key: String(o.key), scale: parseFloat(raw) }
    }
    if (Object.keys(fields).length > 0) root.requested(fields)
  }

  // ---- header ---------------------------------------------------------------

  Item {
    width: parent.width
    implicitHeight: Math.max(scaleTitle.implicitHeight, scaleValue.implicitHeight)

    PanelSectionHeader {
      id: scaleTitle
      anchors.left: parent.left
      anchors.right: scaleValue.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      text: {
        var n = enabledRows().length
        return "SCALE · " + n + (n === 1 ? " DISPLAY" : " DISPLAYS")
      }
      elide: Text.ElideRight
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Text {
      textFormat: Text.PlainText
      id: scaleValue
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: root.headerValue()
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  Text {
    textFormat: Text.PlainText
    width: parent.width
    text: root.captionText()
    color: root.errorText !== "" ? Commons.Color.urgent : root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }

  Column {
    width: parent.width
    spacing: Style.space(3)

    Repeater {
      model: root.rows()

      CursorSurface {
        id: rowSurface
        required property var modelData

        readonly property var stops: modelData.stops
        readonly property bool rowBlocked: modelData.off || root.blocked

        width: parent.width
        height: Math.max(rowContent.implicitHeight + Style.spacing.controlGap, Style.space(36))
        outline: true
        foreground: root.foreground
        accent: root.accent
        opacity: modelData.off ? 0.45 : (root.busy ? 0.5 : 1.0)
        enabled: !rowBlocked

        Behavior on opacity {
          NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        Row {
          id: rowContent
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.leftMargin: Style.space(6)
          anchors.rightMargin: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(4)

          // Rank badge — same number/color the Identify overlay flashes.
          Rectangle {
            visible: rowSurface.modelData.number > 0
            width: Style.space(18)
            height: Style.space(18)
            radius: Math.min(Style.cornerRadius, 9)
            color: Model.displayColor(rowSurface.modelData.number)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: String(rowSurface.modelData.number)
              color: Commons.Color.background
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          Text {
            textFormat: Text.PlainText
            width: Style.space(96)
            anchors.verticalCenter: parent.verticalCenter
            text: rowSurface.modelData.name + (rowSurface.modelData.off ? " · off" : "")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideMiddle
          }

          PanelSlider {
            id: rowSlider
            visible: rowSurface.modelData.hasStops && rowSurface.stops.length > 0
            bar: root.bar
            width: parent.width - Style.space(96) - Style.space(40)
                   - (rowSurface.modelData.number > 0 ? Style.space(18) + Style.space(4) : 0)
            anchors.verticalCenter: parent.verticalCenter
            minimum: 0
            maximum: Math.max(0, rowSurface.stops.length - 1)
            step: 1
            integer: true
            value: rowSurface.modelData.stopIndex
            tickCount: rowSurface.stops.length
            enabled: !rowSurface.rowBlocked

            onMoved: function(v) {
              var idx = Math.round(v)
              var stop = rowSurface.stops[idx]
              if (!stop) return
              root.pendingKey = rowSurface.modelData.key
              root.pendingValue = root.fmtReadout(stop.raw) + "x"
              root.dragSeen = rowSlider.dragging
            }

            onReleased: function(v) {
              var stop = rowSurface.stops[Math.round(v)]
              if (!stop) return
              if (root.dragSeen) {
                root.applyOne(rowSurface.modelData.key, stop.raw)
                root.clearPending()
              } else {
                root.wheelKey = rowSurface.modelData.key
                root.wheelRaw = stop.raw
                root.pendingKey = rowSurface.modelData.key
                root.pendingValue = root.fmtReadout(stop.raw) + "x"
                wheelDebounce.restart()
              }
            }

            onRightClicked: root.applyAll(rowSurface.modelData.scale)
          }

          // No daemon metadata for this mode — say so, keep the readout.
          Text {
            visible: !rowSurface.modelData.hasStops
            width: parent.width - Style.space(96) - Style.space(40)
                   - (rowSurface.modelData.number > 0 ? Style.space(18) + Style.space(4) : 0)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "No clean scale steps for this mode"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }

          Text {
            textFormat: Text.PlainText
            width: Style.space(40)
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
            text: root.pendingKey === rowSurface.modelData.key && root.pendingValue !== ""
              ? root.pendingValue
              : root.fmtReadout(rowSurface.modelData.scale) + "x"
            color: root.pendingKey === rowSurface.modelData.key && root.pendingValue !== ""
              ? root.accent
              : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }
      }
    }
  }
}
