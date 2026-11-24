import QtQuick
import QtQuick3D

// Your membership card, lying on the counter by the till. Glows a little when
// you look at it.
Node {
    id: card
    property bool lit: false
    eulerRotation.y: 74 // casually dropped, roughly facing you
    scale: Qt.vector3d(1.6, 1.6, 1.6) // a bit larger than life, so you can spot it

    Model { // the plastic card
        source: "#Cube"
        scale: Qt.vector3d(0.086, 0.004, 0.054)
        materials: PrincipledMaterial {
            baseColor: "#1747c4"
            roughness: 0.35
            emissiveFactor: card.lit ? Qt.vector3d(0.15, 0.15, 0.05) : Qt.vector3d(0, 0, 0)
        }
    }
    Node { // its face
        position: Qt.vector3d(-4.3, 0.25, -2.7)
        eulerRotation.x: -90
        scale: Qt.vector3d(0.02, 0.02, 0.02)
        Rectangle {
            width: 430
            height: 270
            radius: 18
            color: "#1747c4"
            border.color: card.lit ? "#ffd21f" : "#0b2a80"
            border.width: card.lit ? 10 : 4
            Rectangle { y: 40; width: parent.width; height: 56; color: "#ffd21f" }
            Text {
                x: 22; y: 46
                text: "CINEFY VIDEO"
                color: "#1747c4"
                font.weight: Font.Black
                font.pixelSize: 38
                font.letterSpacing: 3
            }
            Text {
                x: 22; y: 140
                text: (shop.member.name || "MEMBER").toUpperCase()
                color: "white"
                font.weight: Font.Black
                font.pixelSize: 34
            }
            Text {
                x: 22; y: 200
                text: "No. " + (shop.member.memberNo || "")
                color: "#c9d4ff"
                font.pixelSize: 26
            }
        }
    }
}
