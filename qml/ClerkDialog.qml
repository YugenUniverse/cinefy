import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Talking to Dale at the counter: ask for a title and he walks you to it,
// or let him recommend something from your watchlist.
Popup {
    id: popup
    signal goToFilm(int index)
    signal showFilm(int index)

    property string line: ""
    property var results: shop.findFilms(query.text, 7)
    property int selected: 0
    readonly property var greetings: [
        "Hey! Looking for something in particular?",
        "Evening. What are we watching tonight?",
        "Welcome back! Need help finding a tape?",
        "Rain's not stopping, huh. What can I get you?",
        "Hi there. Tell me a title, I know every shelf."
    ]

    onAboutToShow: {
        line = greetings[Math.floor(Math.random() * greetings.length)]
        query.text = ""
        selected = 0
        query.forceActiveFocus()
    }
    onResultsChanged: selected = 0

    function choose(i) {
        if (i < 0 || i >= results.length)
            return
        popup.goToFilm(results[i].index)
        popup.close()
    }
    function suggest() {
        const i = shop.recommend()
        if (i < 0) {
            line = "Your watchlist's empty! Pick anything from Staff Picks."
            return
        }
        const f = shop.film(i)
        line = "You've had “" + f.name + "” on your watchlist for a while. Tonight's the night."
        popup.showFilm(i)
        popup.close()
    }

    parent: Overlay.overlay
    x: (parent.width - width) / 2
    y: parent.height - height - 90
    width: Math.min(parent.width - 80, 760)
    height: content.implicitHeight + 40
    modal: true
    padding: 0
    Overlay.modal: Rectangle { color: "#70000000" }
    background: Rectangle {
        radius: 14
        color: "#f2f4efe0"
        border.color: "#1f3f99"
        border.width: 3
    }

    ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Rectangle { // name badge
                Layout.alignment: Qt.AlignTop
                width: 70; height: 30; radius: 4
                color: "#1f3f99"
                Text {
                    anchors.centerIn: parent
                    text: "DALE"
                    color: "#e3be2a"
                    font.family: Theme.display
                    font.weight: Font.Black
                    font.pixelSize: 15
                    font.letterSpacing: 2
                }
            }
            Text {
                Layout.fillWidth: true
                text: popup.line
                color: "#22305f"
                font.family: Theme.body
                font.pixelSize: 19
                font.italic: true
                wrapMode: Text.Wrap
            }
            Text {
                Layout.alignment: Qt.AlignTop
                text: "✕"
                color: closeHover.hovered ? "#a3261f" : "#22305f"
                font.pixelSize: 20
                HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: popup.close() }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            TextField {
                id: query
                Layout.fillWidth: true
                placeholderText: "Type a title or a year…"
                color: "#22305f"
                placeholderTextColor: "#8a8270"
                font.pixelSize: 16
                leftPadding: 14
                topPadding: 10
                bottomPadding: 10
                background: Rectangle {
                    radius: 6
                    color: "#ffffff"
                    border.color: query.activeFocus ? "#1f3f99" : "#cfc6ad"
                    border.width: 2
                }
                Keys.onDownPressed: popup.selected = Math.min(popup.selected + 1, popup.results.length - 1)
                Keys.onUpPressed: popup.selected = Math.max(popup.selected - 1, 0)
                Keys.onReturnPressed: popup.choose(popup.selected)
                Keys.onEnterPressed: popup.choose(popup.selected)
                Keys.onEscapePressed: popup.close()
            }
            RetroButton {
                text: "SURPRISE ME"
                accent: "#1f3f99"
                onClicked: popup.suggest()
            }
        }

        Repeater {
            model: popup.results
            Rectangle {
                id: row
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: 6
                color: popup.selected === index || rowHover.hovered ? "#e6dcc3" : "transparent"
                Rectangle {
                    id: thumb
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30; height: 44
                    color: "#1b1b1d"
                    Image {
                        anchors.fill: parent
                        source: row.modelData.poster
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
                Text {
                    anchors { left: thumb.right; leftMargin: 12; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    text: row.modelData.name + (row.modelData.year > 0 ? "  <font color='#8a8270'>" + row.modelData.year + "</font>" : "")
                    textFormat: Text.StyledText
                    color: "#22305f"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
                HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: popup.choose(row.index) }
            }
        }
        Text {
            visible: query.text.trim() !== "" && popup.results.length === 0
            text: "Hmm, we don't carry that one."
            color: "#8a8270"
            font.italic: true
            font.pixelSize: 15
        }
        Text {
            text: "↑ ↓ choose · Enter: “take me there” · Esc: never mind"
            color: "#8a8270"
            font.pixelSize: 12
        }
    }
}
