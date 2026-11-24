import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Your membership card: profile stats, rating histogram, favourites, shop settings.
Popup {
    id: popup
    readonly property var m: shop.member

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent.width - 80, 760)
    height: Math.min(parent.height - 60, 800)
    modal: true
    padding: 0
    background: Item {}
    Overlay.modal: Rectangle { color: "#d004060f" }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 }
        NumberAnimation { property: "y"; from: popup.y + 40; duration: 260; easing.type: Easing.OutCubic }
    }

    component Stat: Column {
        property string label
        property string value
        spacing: 2
        Text {
            text: parent.value
            color: Theme.text
            font.family: Theme.display
            font.weight: Font.Black
            font.pixelSize: 30
        }
        Text {
            text: parent.label
            color: "#c9d4ff"
            font.pixelSize: 12
            font.letterSpacing: 1
        }
    }

    ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: scroll.availableWidth
            spacing: 22

            Rectangle {
                id: card
                Layout.fillWidth: true
                Layout.preferredHeight: cardContent.implicitHeight + 48
                radius: 18
                color: Theme.blue
                border.color: "#0b2a80"
                border.width: 2
                clip: true

                Rectangle {
                    width: parent.width
                    height: 54
                    y: 30
                    color: Theme.yellow
                }

                ColumnLayout {
                    id: cardContent
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 28 }
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 54
                        Layout.topMargin: 2
                        Text {
                            text: "CINEFY VIDEO"
                            color: Theme.blue
                            font.family: Theme.display
                            font.weight: Font.Black
                            font.pixelSize: 30
                            font.letterSpacing: 2
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "MEMBERSHIP CARD"
                            color: Theme.blue
                            font.weight: Font.Black
                            font.pixelSize: 14
                            font.letterSpacing: 3
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: (popup.m.name || "").toUpperCase()
                                color: "white"
                                font.family: Theme.display
                                font.weight: Font.Black
                                font.pixelSize: 34
                            }
                            Text {
                                text: "@" + (popup.m.username || "")
                                      + (popup.m.location ? "  ·  " + popup.m.location : "")
                                color: "#c9d4ff"
                                font.pixelSize: 14
                            }
                        }
                        Item { Layout.fillWidth: true }
                        ColumnLayout {
                            spacing: 2
                            Text {
                                Layout.alignment: Qt.AlignRight
                                text: "No. " + (popup.m.memberNo || "")
                                color: "white"
                                font.family: Theme.mono
                                font.pixelSize: 16
                            }
                            Text {
                                Layout.alignment: Qt.AlignRight
                                text: popup.m.since ? "Member since " + popup.m.since : ""
                                color: "#c9d4ff"
                                font.pixelSize: 12
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 5
                        rowSpacing: 14
                        columnSpacing: 24
                        Stat { label: "FILMS WATCHED"; value: popup.m.watched || 0 }
                        Stat { label: "RATED"; value: popup.m.rated || 0 }
                        Stat { label: "AVERAGE"; value: popup.m.average ? "★ " + popup.m.average.toFixed(2) : "–" }
                        Stat { label: "LIKED"; value: popup.m.liked || 0 }
                        Stat { label: "DIARY ENTRIES"; value: popup.m.diary || 0 }
                        Stat { label: "REVIEWS"; value: popup.m.reviews || 0 }
                        Stat { label: "WATCHLIST"; value: popup.m.watchlist || 0 }
                        Stat { label: "TOP GENRE"; value: popup.m.topGenre || "–" }
                        Stat { label: "BUSIEST YEAR"; value: popup.m.busiestYear || "–" }
                        Stat { label: "FAVOURITE DECADE"; value: popup.m.topDecade ? popup.m.topDecade + "s" : "–" }
                    }

                    Text {
                        text: "RATINGS"
                        color: Theme.yellow
                        font.weight: Font.Black
                        font.pixelSize: 13
                        font.letterSpacing: 2
                    }
                    Row {
                        id: histogram
                        readonly property var bars: popup.m.histogram || []
                        readonly property int peak: Math.max(1, ...bars)
                        Layout.fillWidth: true
                        height: 110
                        spacing: 6
                        Repeater {
                            model: histogram.bars
                            Column {
                                required property int modelData
                                required property int index
                                width: (histogram.width - 9 * histogram.spacing) / 10
                                anchors.bottom: parent.bottom
                                spacing: 4
                                Rectangle {
                                    width: parent.width
                                    height: Math.max(3, 80 * modelData / histogram.peak)
                                    radius: 3
                                    color: Theme.yellow
                                    ToolTip.visible: barHover.hovered
                                    ToolTip.text: modelData + (modelData === 1 ? " film" : " films")
                                    HoverHandler { id: barHover }
                                }
                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: index % 2 === 1 ? ((index + 1) / 2) + "★" : ""
                                    color: "#c9d4ff"
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }

                    Text {
                        visible: shop.mostWatched.length > 0
                        text: "MOST RENTED OF ALL TIME"
                        color: Theme.yellow
                        font.weight: Font.Black
                        font.pixelSize: 13
                        font.letterSpacing: 2
                    }
                    Column {
                        Layout.fillWidth: true
                        visible: shop.mostWatched.length > 0
                        spacing: 4
                        Repeater {
                            model: shop.mostWatched
                            Row {
                                required property var modelData
                                required property int index
                                spacing: 12
                                Text {
                                    width: 28
                                    text: (index + 1) + "."
                                    color: "#c9d4ff"
                                    font.pixelSize: 15
                                    horizontalAlignment: Text.AlignRight
                                }
                                Text {
                                    width: 360
                                    text: modelData.name + (modelData.year > 0 ? "  (" + modelData.year + ")" : "")
                                    color: "white"
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: "×" + modelData.count
                                    color: Theme.yellow
                                    font.pixelSize: 15
                                    font.weight: Font.Black
                                }
                            }
                        }
                    }

                    Text {
                        visible: (popup.m.favourites || []).length > 0
                        text: "FAVOURITE FILMS"
                        color: Theme.yellow
                        font.weight: Font.Black
                        font.pixelSize: 13
                        font.letterSpacing: 2
                    }
                    Row {
                        spacing: 12
                        Repeater {
                            model: popup.m.favourites || []
                            Rectangle {
                                required property int modelData
                                readonly property var film: shop.film(modelData)
                                width: 96; height: 144
                                radius: 4
                                color: "#111113"
                                Image {
                                    id: favImage
                                    anchors.fill: parent
                                    anchors.margins: 3
                                    source: parent.film.poster || ""
                                    sourceSize.width: 200
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    visible: status === Image.Ready
                                }
                                BlankLabel {
                                    anchors.fill: parent
                                    anchors.margins: 3
                                    visible: favImage.status !== Image.Ready
                                    title: parent.film.name || ""
                                    year: parent.film.year || 0
                                }
                            }
                        }
                    }
                }
            }

        }
    }
}
