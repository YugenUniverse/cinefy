import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Esc in the shop: resume, settings, controls, go outside, eject, quit.
Popup {
    id: popup
    required property var game // Store3D
    property string page: "main" // main | settings | controls
    signal goOutside
    signal openMap
    signal openCard
    // Esc: back from a sub-page, or close.
    function back() {
        if (page !== "main") page = "main"
        else close()
    }
    closePolicy: Popup.CloseOnPressOutside // Esc is handled by back()
    signal bakeRequested

    onAboutToShow: page = "main"

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: page === "main" ? 380 : Math.min(parent.width - 80, 640)
    height: Math.min(parent.height - 60, page === "main" ? 640 : 680)
    modal: true
    padding: 0
    Overlay.modal: Rectangle { color: "#d004060f" }
    background: Rectangle {
        radius: 14
        color: "#f20a0f26"
        border.color: Theme.yellow
        border.width: 2
    }

    component MenuButton: Rectangle {
        id: mb
        property alias text: mbText.text
        property color accent: Theme.yellow
        signal clicked
        Layout.fillWidth: true
        Layout.preferredHeight: 50
        radius: 8
        color: mbHover.hovered ? accent : "transparent"
        border.color: accent
        border.width: 2
        Text {
            id: mbText
            anchors.centerIn: parent
            color: mbHover.hovered ? Theme.bg : mb.accent
            font.family: Theme.display
            font.weight: Font.Black
            font.pixelSize: 18
            font.letterSpacing: 2
        }
        HoverHandler { id: mbHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: mb.clicked() }
    }
    component Label2: Text {
        color: Theme.dim
        font.pixelSize: 13
    }
    component Heading: Text {
        color: Theme.yellow
        font.family: Theme.display
        font.weight: Font.Black
        font.pixelSize: 14
        font.letterSpacing: 2
        Layout.topMargin: 10
    }

    // ------------------------------------------------ main page
    ColumnLayout {
        visible: popup.page === "main"
        anchors.fill: parent
        anchors.margins: 28
        spacing: 12
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 8
            text: "PAUSED"
            color: Theme.yellow
            font.family: Theme.display
            font.weight: Font.Black
            font.pixelSize: 34
            font.letterSpacing: 6
        }
        MenuButton { text: "RESUME"; accent: Theme.cyan; onClicked: popup.close() }
        MenuButton { text: "MAP  (M)"; onClicked: { popup.close(); popup.openMap() } }
        MenuButton { text: "MEMBERSHIP CARD  (C)"; onClicked: { popup.close(); popup.openCard() } }
        MenuButton { text: "SETTINGS"; onClicked: popup.page = "settings" }
        MenuButton { text: "CONTROLS"; onClicked: popup.page = "controls" }
        MenuButton { text: "GO OUTSIDE"; onClicked: { popup.goOutside(); popup.close() } }
        MenuButton { text: "EJECT TAPE"; accent: Theme.dim; onClicked: shop.eject() }
        MenuButton { text: "QUIT"; accent: Theme.pink; onClicked: ApplicationWindow.window.quitApp() }
        Item { Layout.fillHeight: true }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "CINEFY VIDEO  v" + Qt.application.version
            color: Theme.dim
            font.pixelSize: 11
            font.letterSpacing: 2
        }
    }

    // ------------------------------------------------ settings
    ScrollView {
        id: settingsView
        visible: popup.page === "settings"
        anchors.fill: parent
        anchors.margins: 26
        contentWidth: availableWidth
        clip: true
        ColumnLayout {
            width: settingsView.availableWidth
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "SETTINGS"
                    color: Theme.yellow
                    font.family: Theme.display
                    font.weight: Font.Black
                    font.pixelSize: 26
                    font.letterSpacing: 4
                }
                Item { Layout.fillWidth: true }
                RetroButton { text: "‹ BACK"; accent: Theme.cyan; onClicked: popup.page = "main" }
            }

            Heading { text: "SOUND" }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Label2 { text: "Sound"; Layout.preferredWidth: 110 }
                Switch {
                    id: soundSwitch
                    Layout.preferredWidth: 62
                    Layout.preferredHeight: 34
                    padding: 2
                    checked: !popup.game.muted
                    onToggled: popup.game.muted = !checked
                    indicator: Rectangle {
                        implicitWidth: 58
                        implicitHeight: 30
                        x: (soundSwitch.width - width) / 2
                        y: (soundSwitch.height - height) / 2
                        radius: 15
                        color: soundSwitch.checked ? Theme.cyan : "#2a3050"
                        border.color: soundSwitch.checked ? Theme.cyan : Theme.line
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Rectangle {
                            x: soundSwitch.checked ? parent.width - width - 3 : 3
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24; height: 24; radius: 12
                            color: soundSwitch.checked ? Theme.bg : Theme.dim
                            Behavior on x { NumberAnimation { duration: 120 } }
                        }
                    }
                    contentItem: Item {}
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
                Label2 {
                    text: soundSwitch.checked ? "On" : "Off"
                    color: soundSwitch.checked ? Theme.cyan : Theme.dim
                    font.weight: Font.Bold
                }
                Item { Layout.fillWidth: true }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                enabled: soundSwitch.checked
                opacity: enabled ? 1 : 0.4
                Label2 { text: "Volume"; Layout.preferredWidth: 110 }
                Slider {
                    id: volumeSlider
                    Layout.fillWidth: true
                    from: 0; to: 100
                    stepSize: 1
                    value: Math.round(popup.game.volume * 100)
                    onMoved: popup.game.volume = value / 100
                }
                Label2 {
                    Layout.preferredWidth: 48
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(volumeSlider.value) + "%"
                    color: Theme.text
                    font.weight: Font.Bold
                }
            }

            Heading { text: "GRAPHICS" }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Label2 { text: "Quality"; Layout.preferredWidth: 110 }
                Repeater {
                    model: ["LOW", "MEDIUM", "HIGH"]
                    RetroButton {
                        required property string modelData
                        required property int index
                        text: modelData
                        accent: popup.game.quality === index ? Theme.yellow : Theme.dim
                        onClicked: popup.game.quality = index
                    }
                }
            }
            Label2 {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.pixelSize: 12
                text: ["Smoothest: 3D drawn at 60% resolution, no shadows, lighter rain. For laptops.",
                       "Balanced: 80% resolution, shadows, no edge smoothing.",
                       "Best looking: full resolution, smooth edges, soft corner shading. Needs a good GPU."][popup.game.quality]
            }

            Heading { text: "MOUSE" }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Label2 { text: "Look sensitivity" }
                Slider {
                    Layout.fillWidth: true
                    from: 0.04; to: 0.4
                    value: popup.game.sensitivity
                    onMoved: popup.game.sensitivity = value
                }
                Label2 { text: popup.game.sensitivity.toFixed(2) }
            }

            Heading { text: "LIGHTING"; visible: baker.supported }
            Label2 { text: "Baked lighting: soft bounced light, ray traced once and saved"; visible: baker.supported }
            RowLayout {
                visible: baker.supported
                Layout.fillWidth: true
                spacing: 10
                RetroButton {
                    text: baker.baking ? "BAKING… " + Math.round(baker.progress * 100) + "%"
                          : baker.available ? "BAKE AGAIN" : "BAKE LIGHTING"
                    enabled: !baker.baking
                    onClicked: popup.bakeRequested()
                }
                RetroButton {
                    visible: baker.available
                    text: baker.enabled ? "USING BAKED LIGHT" : "USING LIVE LIGHT"
                    accent: baker.enabled ? Theme.yellow : Theme.dim
                    onClicked: baker.enabled = !baker.enabled
                }
            }
            Label2 {
                visible: baker.supported
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.pixelSize: 12
                text: baker.baking ? baker.status
                      : baker.available ? "Baked for this layout."
                      : "Takes a few seconds. Redo it when your library changes the shelves."
            }

            Heading { text: "COVER ART (TMDB)" }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                RetroField {
                    Layout.fillWidth: true
                    text: shop.tmdbKey
                    placeholderText: "Paste a v3 API key or a v4 read access token"
                    echoMode: activeFocus ? TextInput.Normal : TextInput.Password
                    onEditingFinished: shop.tmdbKey = text
                }
                RetroButton {
                    text: "RESTOCK"
                    enabled: shop.tmdbKey !== "" && !shop.stocking
                    onClicked: shop.restock()
                }
            }
            Label2 {
                visible: shop.tmdbError !== ""
                Layout.fillWidth: true
                text: shop.tmdbError
                color: Theme.red
                wrapMode: Text.Wrap
            }
            Label2 {
                text: "This product uses the TMDB API but is not endorsed or certified by TMDB."
                opacity: 0.6
                font.pixelSize: 11
            }
        }
    }

    // ------------------------------------------------ controls
    ColumnLayout {
        visible: popup.page === "controls"
        anchors.fill: parent
        anchors.margins: 26
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "CONTROLS"
                color: Theme.yellow
                font.family: Theme.display
                font.weight: Font.Black
                font.pixelSize: 26
                font.letterSpacing: 4
            }
            Item { Layout.fillWidth: true }
            RetroButton { text: "‹ BACK"; accent: Theme.cyan; onClicked: popup.page = "main" }
        }
        Repeater {
            model: [
                ["W A S D  /  ↑ ↓", "Walk"],
                ["Shift", "Run"],
                ["← →  /  Q", "Turn"],
                ["Mouse", "Look around"],
                ["Click  /  E", "Pick up a tape, tune the radio, talk to the clerk"],
                ["J  /  Tab", "Hold up your diary (← → month, ↑ ↓ choose, E open)"],
                ["Hold Alt", "Get the pointer back (for the buttons)"],
                ["F", "Call the clerk from anywhere (find a film)"],
                ["M", "Store map (M again to close)"],
                ["C", "Your membership card (it's on the counter too)"],
                ["Esc", "This menu"],
                ["Ctrl+Q", "Quit"],
            ]
            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 16
                Rectangle {
                    Layout.preferredWidth: 190
                    Layout.preferredHeight: 34
                    radius: 6
                    color: "#1a2350"
                    border.color: Theme.line
                    Text {
                        anchors.centerIn: parent
                        text: modelData[0]
                        color: Theme.text
                        font.family: Theme.mono
                        font.pixelSize: 14
                        font.bold: true
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: modelData[1]
                    color: Theme.text
                    font.pixelSize: 15
                }
            }
        }
        Item { Layout.fillHeight: true }
    }
}
