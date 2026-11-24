import QtQuick
import QtQuick.Controls

// Top-down plan of the shop: shelving units, which aisle is where, and you.
// Click an aisle (on the plan or in the list) to walk there.
Popup {
    id: popup
    property real playerX
    property real playerZ
    property real playerYaw
    property int hovered: -1
    signal categoryPicked(int index)

    readonly property var store: shop.store
    readonly property var cats: store.revision >= 0 ? store.categories : []

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent.width - 60, 1180)
    height: parent.height - 60
    modal: true
    padding: 0
    Overlay.modal: Rectangle { color: "#d004060f" }
    background: Rectangle { radius: 12; color: "#f00a0f26"; border.color: Theme.yellow; border.width: 2 }

    Text {
        id: title
        x: 24; y: 16
        text: "STORE MAP"
        color: Theme.yellow
        font.family: Theme.display
        font.weight: Font.Black
        font.pixelSize: 24
        font.letterSpacing: 3
    }
    Text {
        anchors { right: parent.right; rightMargin: 22; verticalCenter: title.verticalCenter }
        text: "✕"
        color: closeHover.hovered ? Theme.yellow : Theme.text
        font.pixelSize: 22
        HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: popup.close() }
    }

    // ---- plan
    Item {
        id: plan
        anchors { left: parent.left; top: title.bottom; bottom: parent.bottom; right: list.left; margins: 20 }
        readonly property real sw: popup.store.halfWidth * 2
        readonly property real sd: popup.store.frontZ - popup.store.backZ
        readonly property real k: Math.min(width / sw, height / sd)
        function px(x) { return (width - sw * k) / 2 + (x + popup.store.halfWidth) * k }
        function pz(z) { return (height - sd * k) / 2 + (z - popup.store.backZ) * k }

        Rectangle { // floor
            x: plan.px(-popup.store.halfWidth)
            y: plan.pz(popup.store.backZ)
            width: plan.sw * plan.k
            height: plan.sd * plan.k
            color: "#2a3040"
            border.color: Theme.line
            border.width: 2
        }
        Rectangle { // door
            x: plan.px(-popup.store.doorHalfWidth)
            y: plan.pz(popup.store.frontZ) - 3
            width: popup.store.doorHalfWidth * 2 * plan.k
            height: 6
            color: Theme.cyan
        }
        Text {
            x: plan.px(0) - width / 2
            y: plan.pz(popup.store.frontZ) + 6
            text: "ENTRANCE"
            color: Theme.cyan
            font.pixelSize: 11
            font.weight: Font.Black
        }
        Rectangle { // counter
            x: plan.px(popup.store.counter.x - 50)
            y: plan.pz(popup.store.counter.z - 165)
            width: 100 * plan.k
            height: 330 * plan.k
            color: Theme.blue
        }
        Repeater { // shelving units, coloured by aisle
            model: popup.cats
            Item {
                id: cat
                required property var modelData
                required property int index
                Repeater {
                    model: cat.modelData.units
                    Rectangle {
                        required property var modelData
                        x: plan.px(modelData.x - 36)
                        y: plan.pz(modelData.z0)
                        width: Math.max(6, 72 * plan.k)
                        height: (modelData.z1 - modelData.z0) * plan.k
                        radius: 2
                        color: cat.modelData.accent
                        opacity: popup.hovered < 0 || popup.hovered === cat.index ? 1 : 0.25
                        HoverHandler { onHoveredChanged: popup.hovered = hovered ? cat.index : -1; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: { popup.categoryPicked(cat.index); popup.close() } }
                    }
                }
            }
        }
        // You.
        Item {
            x: plan.px(popup.playerX)
            y: plan.pz(Math.min(popup.playerZ, popup.store.frontZ + 40))
            rotation: -popup.playerYaw
            Rectangle {
                anchors.centerIn: parent
                width: 14; height: 14; radius: 7
                color: Theme.pink
                border.color: "white"
                border.width: 2
            }
            Rectangle {
                x: -1.5; y: -22
                width: 3; height: 14
                color: Theme.pink
            }
        }
    }

    // ---- aisle list
    ListView {
        id: list
        anchors { right: parent.right; top: title.bottom; bottom: parent.bottom; margins: 20 }
        width: 300
        clip: true
        spacing: 2
        model: popup.cats
        ScrollBar.vertical: ScrollBar {}
        delegate: Rectangle {
            required property var modelData
            required property int index
            width: list.width - 12
            height: 34
            radius: 6
            color: popup.hovered === index ? "#33ffd21f" : "transparent"
            Rectangle {
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 12; height: 12; radius: 6
                color: modelData.accent
            }
            Text {
                anchors { left: parent.left; leftMargin: 30; right: count.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                text: modelData.title
                color: Theme.text
                font.pixelSize: 14
                elide: Text.ElideRight
            }
            Text {
                id: count
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                text: modelData.count
                color: Theme.dim
                font.pixelSize: 12
            }
            HoverHandler { onHoveredChanged: popup.hovered = hovered ? index : -1; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: { popup.categoryPicked(index); popup.close() } }
        }
    }
}
