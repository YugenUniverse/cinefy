import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

// The shop entrance: insert a Letterboxd export to open the doors.
Item {
    id: root

    Carpet { anchors.fill: parent }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#f0070914" }
            GradientStop { position: 0.5; color: "#a0070914" }
            GradientStop { position: 1.0; color: "#f0070914" }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 64, 720)
        spacing: 26

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: signText.implicitWidth + 84
            implicitHeight: signText.implicitHeight + 34
            color: Theme.blue
            radius: 8
            border.color: Theme.yellow
            border.width: 5
            rotation: -2
            Text {
                id: signText
                anchors.centerIn: parent
                text: "CINEFY VIDEO"
                color: Theme.yellow
                font.family: Theme.display
                font.weight: Font.Black
                font.pixelSize: 84
                font.letterSpacing: 4
            }
        }

        NeonText {
            Layout.alignment: Qt.AlignHCenter
            text: "OPEN  ·  BE KIND, REWIND"
            glow: Theme.pink
            font.pixelSize: 26
            flicker: true
        }

        Rectangle {
            id: slot
            Layout.fillWidth: true
            Layout.preferredHeight: 210
            radius: 14
            color: drop.containsDrag ? "#30ffd21f" : "#c00a0e22"
            border.width: 3
            border.color: drop.containsDrag || slotHover.hovered ? Theme.yellow : Theme.line
            Behavior on border.color { ColorAnimation { duration: 150 } }

            Rectangle {
                id: mouth
                anchors.horizontalCenter: parent.horizontalCenter
                y: 34
                width: parent.width * 0.55
                height: 24
                radius: 4
                color: "#000000"
                border.color: "#555555"
                border.width: 2
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.18
                    height: 3
                    color: Theme.red
                    opacity: slotHover.hovered || drop.containsDrag ? 1 : 0.35
                }
            }

            Column {
                anchors.top: mouth.bottom
                anchors.topMargin: 24
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Insert your Letterboxd tape"
                    color: Theme.text
                    font.family: Theme.body
                    font.pixelSize: 26
                    font.weight: Font.Bold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Drop the export .zip here, or click to browse"
                    color: Theme.dim
                    font.pixelSize: 15
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "letterboxd.com → Settings → Data → Export your data"
                    color: Theme.dim
                    opacity: 0.7
                    font.pixelSize: 13
                }
            }

            HoverHandler { id: slotHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: fileDialog.open() }
            DropArea {
                id: drop
                anchors.fill: parent
                onEntered: drag => drag.accepted = drag.hasUrls
                onDropped: dropEvent => {
                    if (dropEvent.hasUrls)
                        shop.loadExport(dropEvent.urls[0])
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: shop.error !== ""
            text: shop.error
            color: Theme.red
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 14
        }

        RetroButton {
            Layout.alignment: Qt.AlignHCenter
            visible: shop.lastExport !== ""
            text: "REOPEN LAST TAPE"
            onClicked: shop.reopenLast()
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: "TMDB API key, used for cover art and wallpapers"
                color: Theme.dim
                font.pixelSize: 13
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                RetroField {
                    id: keyField
                    Layout.fillWidth: true
                    text: shop.tmdbKey
                    placeholderText: "Paste a v3 API key or a v4 read access token"
                    echoMode: activeFocus ? TextInput.Normal : TextInput.Password
                    onEditingFinished: shop.tmdbKey = text
                }
                RetroButton {
                    text: "GET A FREE KEY"
                    accent: Theme.cyan
                    onClicked: Qt.openUrlExternally("https://www.themoviedb.org/settings/api")
                }
            }
            Text {
                text: "This product uses the TMDB API but is not endorsed or certified by TMDB."
                color: Theme.dim
                opacity: 0.55
                font.pixelSize: 11
            }
        }
    }

    Scanlines { anchors.fill: parent }

    RetroButton {
        anchors { top: parent.top; right: parent.right; margins: 24 }
        text: "✕ EXIT"
        accent: Theme.pink
        onClicked: ApplicationWindow.window.quitApp()
    }

    FileDialog {
        id: fileDialog
        title: "Choose your Letterboxd export"
        nameFilters: ["Letterboxd export (*.zip)", "All files (*)"]
        onAccepted: shop.loadExport(selectedFile)
    }
}
