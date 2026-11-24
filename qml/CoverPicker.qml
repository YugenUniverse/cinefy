import QtQuick
import QtQuick.Controls

// Fix a wrong match by hand: search TMDB (films and series) and pick the right
// one. The choice is remembered and never re-matched automatically.
Popup {
    id: popup
    property int filmIndex: -1
    property var results: []
    property bool searching: false
    signal picked

    function show(index, title) {
        filmIndex = index
        query.text = title
        results = []
        open()
        search()
    }
    function search() {
        if (query.text.trim() === "")
            return
        searching = true
        shop.findCandidates(filmIndex, query.text)
    }

    Connections {
        target: shop
        function onCandidatesReady(index, list) {
            if (index !== popup.filmIndex)
                return
            popup.results = list
            popup.searching = false
        }
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent.width - 80, 980)
    height: parent.height - 80
    modal: true
    padding: 0
    Overlay.modal: Rectangle { color: "#c004060f" }
    background: Rectangle { radius: 12; color: "#f60a0f26"; border.color: Theme.yellow; border.width: 2 }

    Text {
        id: heading
        x: 24; y: 18
        text: "WHICH ONE IS IT?"
        color: Theme.yellow
        font.family: Theme.display
        font.weight: Font.Black
        font.pixelSize: 22
        font.letterSpacing: 3
    }
    RetroButton {
        anchors { top: parent.top; right: parent.right; margins: 14 }
        text: "✕ CANCEL"
        accent: Theme.pink
        onClicked: popup.close()
    }
    Row {
        id: bar
        anchors { left: parent.left; right: parent.right; top: heading.bottom; margins: 24; topMargin: 14 }
        spacing: 10
        RetroField {
            id: query
            width: bar.width - searchButton.width - 10
            onAccepted: popup.search()
        }
        RetroButton {
            id: searchButton
            text: "SEARCH"
            onClicked: popup.search()
        }
    }
    Text {
        anchors.centerIn: grid
        visible: popup.searching || popup.results.length === 0
        text: popup.searching ? "Searching TMDB…" : "Nothing found. Try another title."
        color: Theme.dim
        font.pixelSize: 15
    }
    GridView {
        id: grid
        anchors { left: parent.left; right: parent.right; top: bar.bottom; bottom: parent.bottom; margins: 24 }
        clip: true
        cellWidth: 150
        cellHeight: 280
        model: popup.searching ? [] : popup.results
        ScrollBar.vertical: ScrollBar {}
        delegate: Item {
            required property var modelData
            width: grid.cellWidth
            height: grid.cellHeight
            Rectangle {
                anchors.fill: parent
                anchors.margins: 6
                radius: 6
                color: hov.hovered ? "#33ffd21f" : "transparent"
                border.color: hov.hovered ? Theme.yellow : "transparent"
                Column {
                    anchors { fill: parent; margins: 6 }
                    spacing: 4
                    Rectangle {
                        width: parent.width
                        height: width * 1.5
                        color: "#1b1b1d"
                        Image {
                            anchors.fill: parent
                            source: modelData.poster ? "https://image.tmdb.org/t/p/w185" + modelData.poster : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !modelData.poster
                            text: "no poster"
                            color: Theme.dim
                            font.pixelSize: 11
                        }
                    }
                    Text {
                        width: parent.width
                        text: modelData.title
                        color: Theme.text
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: [modelData.year > 0 ? modelData.year : "", modelData.tv ? "TV series" : "",
                               modelData.votes + " votes"].filter(s => s !== "").join(" · ")
                        color: Theme.dim
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
            }
            HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    shop.pinMatch(popup.filmIndex, modelData)
                    popup.picked()
                    popup.close()
                }
            }
        }
    }
}
