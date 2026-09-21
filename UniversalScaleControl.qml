import QtQuick
import qs.Commons
import qs.Ui

// Fork addition: universal scale row on the display panel's front page.
// One control sets the same scale on every enabled output, applied through
// hyprmoncfg's own draft pipeline so the daemon's 10-second confirm-revert
// overlay guards a bad choice. Per-monitor scale stays in the layout editor.
Column {
  id: root

  property var bar: null
  property var profile: null          // current draftProfile from Panel
  property color foreground: Color.foreground
  property color dim: Qt.darker(foreground, 1.5)
  property color accent: Color.accent
  property string fontFamily: Style.font.family
  property bool editPending: false
  property bool previewBusy: false    // a draft apply/preview is in flight

  signal requested(var fieldsByKey)   // { output_key: { scale: "1.6" }, ... }

  spacing: Style.space(5)

  // Scales offered by the stock Omarchy display panel.
  readonly property var scalePresets: ["1", "1.25", "1.6", "2", "3", "4"]

  // The scale every enabled output currently shares, or "" when they differ.
  function sharedScale() {
    if (!profile || !(profile.outputs instanceof Array)) return ""
    var shared = ""
    for (var i = 0; i < profile.outputs.length; i++) {
      var o = profile.outputs[i]
      if (!o || o.enabled === false) continue
      var s = String(o.scale !== undefined && o.scale !== null ? o.scale : "")
      if (s === "") return ""
      if (shared === "") shared = s
      else if (shared !== s) return ""
    }
    return shared
  }

  // Preset matching the shared scale; "mixed" when outputs differ, or the
  // shared value itself when it is not one of the presets.
  function currentLabel() {
    var s = sharedScale()
    if (s === "") return "Mixed"
    var v = parseFloat(s)
    for (var i = 0; i < scalePresets.length; i++) {
      if (Math.abs(parseFloat(scalePresets[i]) - v) < 0.001) return scalePresets[i]
    }
    return s
  }

  // True when every enabled output already sits at this scale.
  function isUniform(target) {
    var s = sharedScale()
    if (s === "") return false
    return Math.abs(parseFloat(s) - target) < 0.001
  }

  function enabledOutputCount() {
    if (!profile || !(profile.outputs instanceof Array)) return 0
    var n = 0
    for (var i = 0; i < profile.outputs.length; i++) {
      if (profile.outputs[i] && profile.outputs[i].enabled !== false) n++
    }
    return n
  }

  function applyScale(target) {
    if (isUniform(target)) return
    var fields = {}
    if (profile && profile.outputs instanceof Array) {
      for (var i = 0; i < profile.outputs.length; i++) {
        var o = profile.outputs[i]
        if (!o || o.enabled === false) continue
        fields[String(o.key)] = { output_key: String(o.key), scale: parseFloat(String(target)) }
      }
    }
    if (Object.keys(fields).length === 0) return
    root.requested(fields)
  }

  Item {
    width: parent.width
    implicitHeight: Math.max(scaleTitle.implicitHeight, scaleValue.implicitHeight)

    PanelSectionHeader {
      id: scaleTitle
      anchors.left: parent.left
      anchors.right: scaleValue.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      text: "UNIVERSAL SCALE · " + root.enabledOutputCount() + (root.enabledOutputCount() === 1 ? " DISPLAY" : " DISPLAYS")
      elide: Text.ElideRight
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Text {
      textFormat: Text.PlainText
      id: scaleValue
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: root.currentLabel()
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  Text {
    textFormat: Text.PlainText
    width: parent.width
    text: "Applies to every display · per-monitor scale lives in the layout editor"
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }

  CursorSurface {
    width: parent.width
    height: Math.max(presetRow.implicitHeight + Style.space(12), Style.space(36))
    outline: true
    foreground: root.foreground
    accent: root.accent
    opacity: root.editPending || root.previewBusy ? 0.5 : 1.0

    Row {
      id: presetRow
      anchors.centerIn: parent
      spacing: Style.space(4)

      Repeater {
        model: root.scalePresets

        Button {
          required property var modelData
          required property int index
          bordered: true
          text: String(modelData)
          selected: root.isUniform(parseFloat(String(modelData)))
          enabled: !(root.editPending || root.previewBusy)
          foreground: root.foreground
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          onClicked: root.applyScale(parseFloat(String(modelData)))
        }
      }
    }
  }
}
