import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  default property alias paneData: content.data
  property string title: ""
  property string meta: ""
  property bool active: false
  // Optional title-bar action (e.g. Identify). Empty string hides the button.
  property string actionLabel: ""
  property color foreground: Color.foreground
  property color dim: Qt.darker(foreground, 1.5)
  property color accent: Color.accent
  property string fontFamily: Style.font.family

  signal actionActivated()

  color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.018)
  borderSpec: Border.controlSpec(active ? "focus" : "normal", foreground, accent)
  radius: Style.cornerRadius

  Item {
    id: titleBar
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.leftMargin: Style.space(10)
    anchors.rightMargin: Style.space(10)
    height: Style.space(28)

    Text {
      textFormat: Text.PlainText
      id: titleLabel
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: root.title
      color: root.active ? root.accent : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
      elide: Text.ElideRight
    }

    Button {
      id: actionButton
      visible: root.actionLabel !== ""
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: root.actionLabel
      bordered: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      fontSize: Style.font.caption
      horizontalPadding: Style.space(8)
      verticalPadding: Style.space(3)
      onClicked: root.actionActivated()
    }

    Text {
      textFormat: Text.PlainText
      anchors.right: root.actionLabel !== "" ? actionButton.left : parent.right
      anchors.rightMargin: root.actionLabel !== "" ? Style.space(8) : 0
      anchors.verticalCenter: parent.verticalCenter
      width: Math.max(0, parent.width - titleLabel.width
        - (root.actionLabel !== "" ? actionButton.width + Style.space(8) : 0)
        - Style.space(12))
      text: root.meta
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideRight
    }
  }

  Item {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: titleBar.bottom
    anchors.bottom: parent.bottom
    anchors.leftMargin: Style.space(10)
    anchors.rightMargin: Style.space(10)
    anchors.bottomMargin: Style.space(10)
  }
}
