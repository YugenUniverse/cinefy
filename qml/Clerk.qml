import QtQuick
import QtQuick3D

// The clerk behind the counter: blue store polo, name tag and cap. He
// breathes, blinks, follows you with his head, and nods while he talks.
Node {
    id: clerk
    property vector3d lookAt: Qt.vector3d(0, 0, 0) // the player
    property bool talking: false
    readonly property vector3d here: clerk.position

    // Head turn towards the player, relative to his body (which faces -X).
    readonly property real headYaw: {
        const a = Math.atan2(lookAt.x - here.x, lookAt.z - here.z) * 180 / Math.PI
        let rel = a + 90
        while (rel > 180) rel -= 360
        while (rel < -180) rel += 360
        return Math.max(-65, Math.min(65, rel))
    }
    property real smoothYaw: headYaw
    Behavior on smoothYaw { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
    property real breath: 0
    SequentialAnimation on breath {
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 1900; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 2100; easing.type: Easing.InOutSine }
    }
    property real blink: 1
    SequentialAnimation on blink {
        loops: Animation.Infinite
        PauseAnimation { duration: 3400 }
        NumberAnimation { to: 0.1; duration: 70 }
        NumberAnimation { to: 1; duration: 90 }
        PauseAnimation { duration: 1800 }
        NumberAnimation { to: 0.1; duration: 70 }
        NumberAnimation { to: 1; duration: 90 }
    }
    property real nod: 0
    SequentialAnimation on nod {
        running: clerk.talking
        loops: Animation.Infinite
        NumberAnimation { to: 6; duration: 260; easing.type: Easing.InOutSine }
        NumberAnimation { to: -2; duration: 300; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 240 }
    }

    eulerRotation.y: -90 // faces the shop floor

    component Skin: PrincipledMaterial { baseColor: "#d6a07c"; roughness: 0.65 }
    component Cloth: PrincipledMaterial { roughness: 0.85 }
    component Limb: Model { source: "#Cylinder" }

    // Legs (mostly hidden by the counter).
    Repeater3D {
        model: 2
        Limb {
            required property int index
            position: Qt.vector3d((index === 0 ? -1 : 1) * 9, 45, 0)
            scale: Qt.vector3d(0.13, 0.9, 0.13)
            materials: Cloth { baseColor: "#2b3448" }
        }
    }
    // Torso: blue polo with a yellow collar and a name tag.
    Node {
        y: 92
        scale: Qt.vector3d(1, 1 + 0.012 * clerk.breath, 1 + 0.02 * clerk.breath)
        Model {
            source: "#Cube"
            y: 32
            scale: Qt.vector3d(0.4, 0.62, 0.24)
            materials: Cloth { baseColor: "#1f3f99" }
        }
        Model { // collar
            source: "#Cube"
            y: 63
            scale: Qt.vector3d(0.22, 0.04, 0.2)
            materials: Cloth { baseColor: "#e3be2a" }
        }
        Model { // shoulders
            source: "#Sphere"
            y: 58
            scale: Qt.vector3d(0.46, 0.14, 0.26)
            materials: Cloth { baseColor: "#1f3f99" }
        }
        Node { // name tag
            position: Qt.vector3d(5, 50, 12.2)
            Model {
                source: "#Rectangle"
                scale: Qt.vector3d(0.11, 0.045, 1)
                materials: PrincipledMaterial { baseColor: "#f4efe0"; roughness: 0.4 }
            }
            Node {
                position: Qt.vector3d(-5, 2, 0.1)
                scale: Qt.vector3d(0.05, 0.05, 0.05)
                Text {
                    width: 200
                    text: "DALE"
                    color: "#1f3f99"
                    horizontalAlignment: Text.AlignHCenter
                    font.weight: Font.Black
                    font.pixelSize: 70
                }
            }
        }
    }
    // Arms: upper arms down, forearms forward resting on the counter.
    Repeater3D {
        model: 2
        Node {
            required property int index
            readonly property int s: index === 0 ? -1 : 1
            position: Qt.vector3d(s * 23, 148, 0)
            Limb { // upper arm
                y: -15
                eulerRotation.z: s * -6
                scale: Qt.vector3d(0.1, 0.32, 0.1)
                materials: Cloth { baseColor: "#1f3f99" }
            }
            Limb { // forearm, forward and slightly in
                position: Qt.vector3d(-s * 3, -34, 14)
                eulerRotation: Qt.vector3d(78, 0, s * -10)
                scale: Qt.vector3d(0.085, 0.3, 0.085)
                materials: Skin {}
            }
            Model { // hand on the counter
                source: "#Sphere"
                position: Qt.vector3d(-s * 6, -38, 30)
                scale: Qt.vector3d(0.09, 0.05, 0.11)
                materials: Skin {}
            }
        }
    }
    // Head, which follows you.
    Node {
        position: Qt.vector3d(0, 160, 0)
        eulerRotation: Qt.vector3d(clerk.nod, clerk.smoothYaw, 0)
        Limb { // neck
            y: 4
            scale: Qt.vector3d(0.08, 0.1, 0.08)
            materials: Skin {}
        }
        Model { // head
            source: "#Sphere"
            y: 17
            scale: Qt.vector3d(0.2, 0.24, 0.21)
            materials: Skin {}
        }
        Model { // hair at the back and sides
            source: "#Sphere"
            position: Qt.vector3d(0, 20, -2.5)
            scale: Qt.vector3d(0.21, 0.22, 0.2)
            materials: PrincipledMaterial { baseColor: "#3a2618"; roughness: 0.9 }
        }
        Model { // cap
            source: "#Sphere"
            position: Qt.vector3d(0, 25, 0)
            scale: Qt.vector3d(0.215, 0.13, 0.22)
            materials: Cloth { baseColor: "#1f3f99" }
        }
        Model { // cap brim
            source: "#Cube"
            position: Qt.vector3d(0, 25.5, 12)
            eulerRotation.x: -8
            scale: Qt.vector3d(0.17, 0.012, 0.11)
            materials: Cloth { baseColor: "#e3be2a" }
        }
        Repeater3D { // eyes
            model: 2
            Model {
                required property int index
                source: "#Sphere"
                position: Qt.vector3d((index === 0 ? -1 : 1) * 4, 19, 9.6)
                scale: Qt.vector3d(0.022, 0.022 * clerk.blink, 0.012)
                materials: PrincipledMaterial { baseColor: "#1a1410"; roughness: 0.3 }
            }
        }
        Model { // nose
            source: "#Sphere"
            position: Qt.vector3d(0, 15.5, 10.4)
            scale: Qt.vector3d(0.03, 0.04, 0.03)
            materials: Skin {}
        }
        Model { // mouth, opens a little while talking
            source: "#Cube"
            position: Qt.vector3d(0, 10.5, 9.8)
            scale: Qt.vector3d(0.05, clerk.talking ? 0.012 + 0.008 * Math.abs(clerk.nod) / 6 : 0.006, 0.01)
            materials: PrincipledMaterial { baseColor: "#6b2b26"; roughness: 0.7 }
        }
    }
}
