import QtQuick
import QtQuick.Controls

TextField {
    id: field
    color: Theme.text
    placeholderTextColor: "#6a7395"
    selectionColor: Theme.blue
    font.family: Theme.body
    font.pixelSize: 15
    leftPadding: 14
    rightPadding: 14
    topPadding: 10
    bottomPadding: 10
    background: Rectangle {
        radius: 6
        color: "#cc0a0e22"
        border.width: 2
        border.color: field.activeFocus ? Theme.cyan : Theme.line
    }
}
