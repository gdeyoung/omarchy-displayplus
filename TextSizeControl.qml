import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Fork addition: text-size control on the display panel's front page.
// Same semantics as the stock omarchy.monitor panel: a slider that snaps to
// curated stops, driving the omarchy-display-text-size CLI; the knob follows
// the shell's live base size when nothing is in flight.
Column {
  id: root

  property var bar: null
  property color foreground: Color.foreground
  property color dim: Qt.darker(foreground, 1.5)
  property color accent: Color.accent
  property string fontFamily: Style.font.family

  // Curated macOS-style notches (px), same list as the stock panel.
  readonly property var textSizeStops: [9, 10, 11, 12, 14, 16, 20]
  // Pending stop while a change is in flight; -1 = follow live base size.
  property int textSizePreviewIndex: -1

  spacing: Style.space(5)

  function nearestTextStop(px) {
    var best = 0
    var bestDist = 1e9
    for (var i = 0; i < textSizeStops.length; i++) {
      var d = Math.abs(textSizeStops[i] - px)
      if (d < bestDist) { bestDist = d; best = i }
    }
    return best
  }

  function currentTextIndex() {
    return textSizePreviewIndex >= 0 ? textSizePreviewIndex : nearestTextStop(Style.font.baseSize)
  }

  function displayedTextPx() {
    return textSizePreviewIndex >= 0 ? textSizeStops[textSizePreviewIndex] : Style.font.baseSize
  }

  function applyStopIndex(idx) {
    if (idx < 0 || idx >= textSizeStops.length) return
    textSizePreviewIndex = idx
    textSetProc.command = ["omarchy-display-text-size", String(textSizeStops[idx])]
    if (!textSetProc.running) textSetProc.running = true
  }

  Item {
    width: parent.width
    implicitHeight: Math.max(textTitle.implicitHeight, textValue.implicitHeight)

    PanelSectionHeader {
      id: textTitle
      anchors.left: parent.left
      anchors.right: textValue.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      text: "TEXT SIZE"
      elide: Text.ElideRight
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Text {
      textFormat: Text.PlainText
      id: textValue
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: root.displayedTextPx() + "px"
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  Text {
    textFormat: Text.PlainText
    width: parent.width
    text: "Shell, apps, and terminals together"
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }

  CursorSurface {
    width: parent.width
    height: Math.max(textSlider.implicitHeight + Style.spacing.controlGap, Style.space(36))
    outline: true
    foreground: root.foreground
    accent: root.accent

    PanelSlider {
      id: textSlider
      bar: root.bar
      anchors.fill: parent
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      // The slider position indexes the stop list; the knob snaps stop to stop.
      minimum: 0
      maximum: root.textSizeStops.length - 1
      step: 1
      value: root.currentTextIndex()
      integer: true
      onMoved: function(next) {
        // Live preview while dragging: apply each stop as it is crossed.
        root.applyStopIndex(Math.round(next))
      }
      onReleased: function(next) {
        root.applyStopIndex(Math.round(next))
      }
    }
  }

  Process {
    id: textSetProc
    command: ["true"]
    onExited: function(exitCode, exitStatus) {
      // CLI succeeded: the shell's Style engine re-reads the config; stop
      // overriding the displayed value and follow the live base size again.
      if (exitCode === 0) root.textSizePreviewIndex = -1
    }
  }
}
