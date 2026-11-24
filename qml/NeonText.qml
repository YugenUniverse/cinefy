import QtQuick
import QtQuick.Effects

// Glowing neon-tube text that occasionally flickers. The glow is a blurred,
// tinted copy drawn behind the text, so the text itself always renders.
Item {
    id: root
    property alias text: label.text
    property alias font: label.font
    property color glow: Theme.pink
    property bool flicker: false

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    MultiEffect {
        anchors.fill: label
        source: label
        autoPaddingEnabled: true
        blurEnabled: true
        blur: 1.0
        blurMax: 32
        colorization: 1.0
        colorizationColor: root.glow
        brightness: 0.4
    }

    Text {
        id: label
        color: Qt.lighter(root.glow, 1.45)
        font.family: Theme.display
        font.weight: Font.Black
        font.pixelSize: 40
        font.letterSpacing: 3
    }

    SequentialAnimation on opacity {
        running: root.flicker
        loops: Animation.Infinite
        PauseAnimation { duration: 4300 }
        NumberAnimation { to: 0.3; duration: 50 }
        NumberAnimation { to: 1; duration: 70 }
        NumberAnimation { to: 0.55; duration: 40 }
        NumberAnimation { to: 1; duration: 140 }
        PauseAnimation { duration: 2700 }
    }
}
