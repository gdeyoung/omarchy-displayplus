import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "gdeyoung.hyprmoncfg"

  // Identify overlay lives here, not in the service: quickshell 0.3.1 does not
  // paint windows owned by a parentless third-party service Item. Bar widgets
  // render windows reliably (same context as the popover). Ranks/colors are
  // shared with the canvas badges via Model.displayNumberMap/displayColor.
  property bool identifying: false
  readonly property var identifyRanks: {
    var screens = Quickshell.screens || []
    var items = []
    for (var i = 0; i < screens.length; i++) {
      var s = screens[i]
      if (!s) continue
      items.push({
        name: String(s.name || ""),
        x: Number(s.x !== undefined ? s.x : 0),
        y: Number(s.y !== undefined ? s.y : 0)
      })
    }
    items.sort(function(left, right) {
      var dx = left.x - right.x
      return dx !== 0 ? dx : left.y - right.y
    })
    var map = {}
    for (var j = 0; j < items.length; j++) map[items[j].name] = j + 1
    return map
  }

  function identifyDisplays() {
    root.identifying = true
    identifyTimer.restart()
  }

  // CLI/hotkey surface: qs ipc call hyprmoncfg identify (bindable in Hyprland).
  IpcHandler {
    target: "hyprmoncfg"
    function identify(): void { root.identifyDisplays() }
  }

  Timer {
    id: identifyTimer
    interval: 3000
    onTriggered: root.identifying = false
  }

  // One overlay per physical screen. The bar widget is instantiated once per
  // bar (per screen); each instance's overlay targets the screen its bar
  // window is on — read from the widget's own window, which always knows.
  PanelWindow {
    id: identifyWindow
    readonly property string screenName: identifyWindow.screen
      && identifyWindow.screen.name !== undefined
      ? String(identifyWindow.screen.name) : ""
    readonly property int rank: root.identifyRanks[screenName] || 0
    readonly property color tint: Model.displayColor(rank)

    visible: root.identifying
    color: "transparent"
    WlrLayershell.namespace: "hyprmoncfg-identify"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }


    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
      onClicked: root.identifying = false
    }

    Rectangle {
      id: identifyBadge
      anchors.centerIn: parent
      width: Math.min(parent.width * 0.5, parent.height * 0.5, 460)
      height: width
      radius: width / 6
      color: Qt.rgba(identifyWindow.tint.r, identifyWindow.tint.g, identifyWindow.tint.b, 0.22)
      border.color: identifyWindow.tint
      border.width: Math.max(3, Style.space(1.5))

      Column {
        anchors.centerIn: parent
        spacing: Style.space(4)

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: identifyWindow.rank > 0 ? String(identifyWindow.rank) : "?"
          color: identifyWindow.tint
          font.family: Style.font.family
          font.pixelSize: identifyBadge.width * 0.42
          font.bold: true
        }

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: identifyWindow.screenName
          color: Color.foreground
          opacity: 0.8
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
        }
      }
    }
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("identifyProxy" in target) target.identifyProxy = root
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool backendConnected: panelLoader.item ? panelLoader.item.backendConnected === true : false
  readonly property bool barIconDimmed: panelLoader.item ? panelLoader.item.barIconDimmed === true : false
  readonly property int monitorCount: panelLoader.item ? panelLoader.item.monitorCount : Quickshell.screens.length
  readonly property string activeProfile: panelLoader.item ? panelLoader.item.activeProfile : ""

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.monitorCount > 1 ? "󰍺" : "󰍹"
    dimmed: root.barIconDimmed
    tooltipText: root.activeProfile !== "" ? "Display · " + root.activeProfile : "Display · hyprmoncfg"
    iconComponent: Component {
      Item {
        OpticalGlyph {
          id: barDisplayGlyph
          anchors.fill: parent
          text: button.text
          color: button.foreground
          fontFamily: button.fontFamily
          fontSize: button.fontSize
        }

        Text {
          textFormat: Text.PlainText
          visible: root.backendConnected
          anchors.right: barDisplayGlyph.right
          anchors.bottom: barDisplayGlyph.bottom
          anchors.rightMargin: -Style.space(1)
          anchors.bottomMargin: -Style.space(1)
          text: "󰄬"
          color: Color.accent
          font.family: button.fontFamily
          font.pixelSize: Math.max(7, Math.round(button.fontSize * 0.45))
          font.bold: true
        }
      }
    }

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton) root.togglePanel()
    }
  }
}
