import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A tape taken off the shelf: the case (click to flip it over) and your rental record.
Popup {
    id: popup
    property var film: ({})
    property bool flipped: false
    signal locate(int index)

    function show(index) {
        film = shop.film(index)
        flipped = false
        open()
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent.width - 80, 1040)
    height: Math.min(parent.height - 80, 660)
    modal: true
    padding: 0
    background: Item {}
    Overlay.modal: Rectangle { color: "#d004060f" }

    CoverPicker {
        id: coverPicker
        onPicked: popup.film = shop.film(popup.film.index)
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 }
        NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 220; easing.type: Easing.OutBack }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: 120 }
    }

    component SectionTitle: Text {
        color: Theme.yellow
        font.family: Theme.display
        font.weight: Font.Black
        font.pixelSize: 15
        font.letterSpacing: 2
        Layout.topMargin: 10
    }
    component Chip: Rectangle {
        property alias text: chipText.text
        property color tint: Theme.cyan
        implicitWidth: chipText.implicitWidth + 18
        implicitHeight: 26
        radius: 13
        color: Qt.rgba(tint.r, tint.g, tint.b, 0.14)
        border.color: tint
        Text {
            id: chipText
            anchors.centerIn: parent
            color: Theme.text
            font.pixelSize: 12
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 34

        Flipable {
            id: flip
            Layout.fillHeight: true
            Layout.preferredWidth: height * 0.64

            transform: Rotation {
                origin.x: flip.width / 2
                origin.y: flip.height / 2
                axis { x: 0; y: 1; z: 0 }
                angle: popup.flipped ? 180 : 0
                Behavior on angle { NumberAnimation { duration: 520; easing.type: Easing.InOutCubic } }
            }

            front: Rectangle {
                width: flip.width
                height: flip.height
                radius: 8
                color: "#111113"
                border.color: "#2b2b30"
                Image {
                    id: bigCover
                    anchors.fill: parent
                    anchors.margins: 9
                    source: popup.film.poster || ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }
                BlankLabel {
                    anchors.fill: parent
                    anchors.margins: 9
                    visible: bigCover.status !== Image.Ready
                    title: popup.film.name || ""
                    year: popup.film.year || 0
                    accent: popup.film.spineColor || Theme.blue
                }
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 9
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#30ffffff" }
                        GradientStop { position: 0.3; color: "#00ffffff" }
                        GradientStop { position: 1.0; color: "#14ffffff" }
                    }
                }
            }

            back: Rectangle {
                width: flip.width
                height: flip.height
                radius: 8
                color: "#0f1328"
                border.color: Theme.blue
                border.width: 3

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: width * 0.5625
                        color: "#000000"
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: popup.film.backdrop || ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: (popup.film.name || "").toUpperCase()
                        color: Theme.yellow
                        font.family: Theme.display
                        font.weight: Font.Black
                        font.pixelSize: 20
                        wrapMode: Text.Wrap
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: popup.film.overview
                              || "No synopsis on file. The last renter must have scratched it off."
                        color: Theme.text
                        font.pixelSize: 13
                        lineHeight: 1.2
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                    }
                    Row {
                        Layout.alignment: Qt.AlignLeft
                        spacing: 2
                        Repeater {
                            model: 34
                            Rectangle {
                                width: [1, 2, 3, 1, 2][(index * 7 + (popup.film.year || 0)) % 5]
                                height: 30
                                color: Theme.text
                            }
                        }
                    }
                    Text {
                        text: "VHS · HI-FI STEREO · BE KIND, REWIND"
                        color: Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: 10
                    }
                }
            }

            TapHandler { onTapped: popup.flipped = !popup.flipped }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: "#f00a0f26"
            border.color: Theme.yellow
            border.width: 2

            // Put back: always in the card's top-right corner.
            RetroButton {
                anchors { top: parent.top; right: parent.right; margins: 16 }
                z: 2
                text: "✕ PUT BACK"
                accent: Theme.pink
                onClicked: popup.close()
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 26
                spacing: 12

                ScrollView {
                    id: scroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: scroll.availableWidth
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            Layout.rightMargin: 130
                            text: popup.film.name || ""
                            color: Theme.text
                            font.family: Theme.display
                            font.weight: Font.Black
                            font.pixelSize: 36
                            wrapMode: Text.Wrap
                        }
                        Text {
                            Layout.fillWidth: true
                            text: [popup.film.year > 0 ? popup.film.year : "",
                                   popup.film.originalTitle && popup.film.originalTitle !== popup.film.name
                                       ? popup.film.originalTitle : ""].filter(s => s !== "").join("  ·  ")
                            color: Theme.dim
                            font.pixelSize: 15
                            wrapMode: Text.Wrap
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: (popup.film.genres || []).length > 0
                            Repeater {
                                model: popup.film.genres || []
                                Chip { required property string modelData; text: modelData; tint: Theme.cyan }
                            }
                        }
                        Row {
                            spacing: 14
                            Layout.topMargin: 6
                            Text {
                                text: popup.film.rating > 0 ? Theme.stars(popup.film.rating) : "Not rated"
                                color: popup.film.rating > 0 ? Theme.yellow : Theme.dim
                                font.pixelSize: popup.film.rating > 0 ? 30 : 16
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                visible: popup.film.liked === true
                                text: "♥"
                                color: Theme.pink
                                font.pixelSize: 28
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Chip {
                                visible: popup.film.watchCount > 1
                                text: "RENTED ×" + popup.film.watchCount
                                tint: "#ffb300"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Chip {
                                visible: popup.film.isTv === true
                                text: "TV SERIES"
                                tint: "#7ee081"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Chip {
                                visible: popup.film.favourite === true
                                text: "ALL-TIME FAVOURITE"
                                tint: Theme.pink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        SectionTitle { text: "RENTAL HISTORY" }
                        Repeater {
                            model: popup.film.diary || []
                            RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 12
                                Text {
                                    text: modelData.date
                                    color: Theme.text
                                    font.family: Theme.mono
                                    font.pixelSize: 13
                                    Layout.preferredWidth: 110
                                }
                                Text {
                                    text: Theme.stars(modelData.rating)
                                    color: Theme.yellow
                                    font.pixelSize: 14
                                    Layout.preferredWidth: 90
                                }
                                Text {
                                    visible: modelData.rewatch
                                    text: "REWATCH"
                                    color: Theme.red
                                    font.pixelSize: 11
                                    font.weight: Font.Black
                                }
                                Text {
                                    visible: modelData.tags !== ""
                                    text: modelData.tags
                                    color: Theme.dim
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Item { Layout.fillWidth: true; visible: modelData.tags === "" }
                            }
                        }
                        Text {
                            visible: (popup.film.diary || []).length === 0
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            color: Theme.dim
                            font.pixelSize: 14
                            text: popup.film.watched
                                  ? (popup.film.watchedOn ? "Watched, logged " + popup.film.watchedOn
                                                          : "Watched, no diary entries")
                                  : popup.film.inWatchlist
                                    ? "Not rented yet. On your watchlist since " + popup.film.watchlistedOn + "."
                                    : "Not rented yet."
                        }

                        SectionTitle {
                            text: "YOUR REVIEW"
                            visible: (popup.film.reviews || []).length > 0
                        }
                        Repeater {
                            model: popup.film.reviews || []
                            ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 4
                                Text {
                                    Layout.fillWidth: true
                                    text: "“" + modelData.text + "”"
                                    color: Theme.text
                                    font.pixelSize: 15
                                    font.italic: true
                                    wrapMode: Text.Wrap
                                    textFormat: Text.PlainText
                                }
                                Text {
                                    text: modelData.date
                                    color: Theme.dim
                                    font.pixelSize: 12
                                }
                            }
                        }

                        SectionTitle {
                            text: "ON THE STAFF LISTS"
                            visible: (popup.film.lists || []).length > 0
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: (popup.film.lists || []).length > 0
                            Repeater {
                                model: popup.film.lists || []
                                Chip { required property string modelData; text: modelData; tint: "#b98cff" }
                            }
                        }
                    }
                }

                // Wraps onto a second line rather than spilling past the card.
                Flow {
                    Layout.fillWidth: true
                    spacing: 10
                    RetroButton {
                        text: popup.flipped ? "FRONT OF CASE" : "FLIP CASE"
                        accent: Theme.cyan
                        onClicked: popup.flipped = !popup.flipped
                    }
                    RetroButton {
                        text: "FIND ON SHELF"
                        accent: Theme.cyan
                        onClicked: { popup.locate(popup.film.index); popup.close() }
                    }
                    RetroButton {
                        text: "OPEN ON LETTERBOXD"
                        onClicked: shop.openOnLetterboxd(popup.film.index)
                    }
                    RetroButton {
                        text: "WRONG COVER?"
                        accent: Theme.dim
                        onClicked: coverPicker.show(popup.film.index, popup.film.name)
                    }
                }
            }
        }
    }
}
