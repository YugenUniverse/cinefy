import QtQuick

// A tape with no cover art: a hand-written sticker on a black cassette.
Rectangle {
    id: label
    property string title
    property int year: 0
    property color accent: Theme.blue
    property bool spinning: false

    color: "#1b1b1d"

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.64
        spacing: label.width * 0.16
        Repeater {
            model: 2
            Rectangle {
                width: label.width * 0.24
                height: width
                radius: width / 2
                color: "#0c0c0c"
                border.color: "#3a3a3a"
                border.width: 2
                Repeater {
                    model: 3
                    Rectangle {
                        x: parent.width / 2 - 1
                        y: 3
                        width: 2
                        height: parent.height / 2 - 3
                        color: "#3a3a3a"
                        transformOrigin: Item.Bottom
                        rotation: index * 120
                    }
                }
                RotationAnimation on rotation {
                    running: label.spinning
                    loops: Animation.Infinite
                    from: 0; to: 360
                    duration: 1800
                }
            }
        }
    }

    Rectangle {
        x: 8
        y: 12
        width: parent.width - 16
        height: parent.height * 0.46
        radius: 2
        color: "#f3eee0"
        Rectangle { width: parent.width; height: 8; color: label.accent }
        Text {
            anchors { fill: parent; margins: 8; topMargin: 14; bottomMargin: 18 }
            text: label.title
            color: "#1d2a6b"
            font.family: Theme.body
            font.pixelSize: Math.max(16, label.width * 0.09)
            font.weight: Font.Bold
            font.italic: true
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            fontSizeMode: Text.Fit
            minimumPixelSize: 9
            elide: Text.ElideRight
        }
        Text {
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 4 }
            text: label.year > 0 ? label.year : ""
            color: "#6b6b6b"
            font.pixelSize: 10
        }
    }
}
