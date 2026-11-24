import QtQuick
import QtQuick.Controls

Button {
    id: button
    property color accent: Theme.yellow

    font.family: Theme.body
    font.pixelSize: 14
    font.weight: Font.Bold
    font.letterSpacing: 1
    topPadding: 10
    bottomPadding: 10
    leftPadding: 18
    rightPadding: 18

    contentItem: Text {
        text: button.text
        font: button.font
        color: button.down ? Theme.bg : button.accent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: 6
        color: button.down ? button.accent
                           : button.hovered ? Qt.rgba(button.accent.r, button.accent.g, button.accent.b, 0.16)
                                            : "#99081030"
        border.color: button.accent
        border.width: 2
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
