import QtQuick
import QtQuick3D

// The back of the shop: an arcade corner in the middle, a popcorn machine on
// one side, and the staff door with a trolley of returns on the other.
Node {
    id: back
    readonly property var store: shop.store
    readonly property real wallZ: store.backZ + 1
    readonly property real side: store.halfWidth

    component Box: Model {
        property color color: "#333333"
        property real rough: 0.6
        property real metal: 0
        source: "#Cube"
        materials: PrincipledMaterial { baseColor: color; roughness: rough; metalness: metal }
    }

    // ------------------------------------------------ arcade corner
    // Three upright cabinets with made-up games; their screens run little
    // attract-mode loops.
    Repeater3D {
        model: [
            { name: "STAR RUNNER", hue: "#ff3d9a", kind: 0 },
            { name: "TAPE INVADERS", hue: "#3df5ff", kind: 1 },
            { name: "REWIND RACER", hue: "#ffd21f", kind: 2 },
        ]
        Node {
            id: cab
            required property var modelData
            required property int index
            position: Qt.vector3d(back.side * 0.3 + (index - 1) * 105, 0, back.wallZ + 42)
            eulerRotation.y: (index - 1) * -7
            Box { // body
                color: "#18181c"
                rough: 0.5
                position: Qt.vector3d(0, 88, 0)
                scale: Qt.vector3d(0.72, 1.76, 0.7)
            }
            Box { // coloured side stripes
                color: cab.modelData.hue
                rough: 0.4
                position: Qt.vector3d(0, 88, 0)
                scale: Qt.vector3d(0.74, 1.2, 0.04)
            }
            Model { // lit marquee with the game's name
                source: "#Rectangle"
                position: Qt.vector3d(0, 160, 35.4)
                scale: Qt.vector3d(0.66, 0.2, 1)
                materials: PrincipledMaterial {
                    lighting: PrincipledMaterial.NoLighting
                    baseColorMap: Texture {
                        sourceItem: Rectangle {
                            width: 330
                            height: 100
                            color: "#0b0b12"
                            border.color: cab.modelData.hue
                            border.width: 6
                            Text {
                                anchors.centerIn: parent
                                width: parent.width - 20
                                horizontalAlignment: Text.AlignHCenter
                                fontSizeMode: Text.HorizontalFit
                                text: cab.modelData.name
                                color: cab.modelData.hue
                                font.weight: Font.Black
                                font.italic: true
                                font.pixelSize: 44
                            }
                        }
                    }
                }
            }
            Box { // control panel, sloped
                color: "#2a2a30"
                position: Qt.vector3d(0, 98, 40)
                eulerRotation.x: 22
                scale: Qt.vector3d(0.7, 0.06, 0.34)
            }
            Repeater3D { // joystick and two buttons
                model: 3
                Model {
                    required property int index
                    source: index === 0 ? "#Cylinder" : "#Sphere"
                    position: Qt.vector3d(-16 + index * 14, index === 0 ? 108 : 103, 42)
                    scale: index === 0 ? Qt.vector3d(0.02, 0.12, 0.02) : Qt.vector3d(0.045, 0.03, 0.045)
                    materials: PrincipledMaterial {
                        baseColor: index === 0 ? "#111111" : (index === 1 ? "#d6231f" : cab.modelData.hue)
                        roughness: 0.25
                    }
                }
            }
            Model { // the screen, set into the front of the cabinet
                source: "#Rectangle"
                position: Qt.vector3d(0, 128, 35.6)
                eulerRotation.x: -10
                scale: Qt.vector3d(0.56, 0.42, 1)
                materials: PrincipledMaterial {
                    lighting: PrincipledMaterial.NoLighting
                    baseColorMap: Texture {
                        sourceItem: Canvas {
                            id: screen
                            width: 160
                            height: 120
                            property int frame: 0
                            Component.onCompleted: requestPaint()
                            Timer {
                                interval: 90
                                running: true
                                repeat: true
                                onTriggered: { screen.frame++; screen.requestPaint() }
                            }
                            onPaint: {
                                const ctx = getContext("2d")
                                const f = frame
                                ctx.fillStyle = "#05050c"
                                ctx.fillRect(0, 0, width, height)
                                ctx.fillStyle = cab.modelData.hue
                                if (cab.modelData.kind === 0) { // star field + ship
                                    for (let i = 0; i < 40; ++i) {
                                        const x = (i * 37 + f * (1 + i % 3)) % width
                                        ctx.fillRect(width - x, (i * 53) % height, 2, 1)
                                    }
                                    ctx.fillRect(24, 56 + 8 * Math.sin(f * 0.2), 14, 6)
                                } else if (cab.modelData.kind === 1) { // marching invaders
                                    const dx = (f % 40) < 20 ? f % 20 : 20 - f % 20
                                    for (let r = 0; r < 3; ++r)
                                        for (let c = 0; c < 6; ++c)
                                            ctx.fillRect(18 + dx + c * 20, 16 + r * 16 + Math.floor(f / 40) % 3 * 4, 10, 7)
                                    ctx.fillRect(70 + 30 * Math.sin(f * 0.15), 104, 16, 6)
                                } else { // road racing towards you
                                    for (let i = 0; i < 8; ++i) {
                                        const y = 50 + ((i * 12 + f * 4) % 70)
                                        const w = (y - 40) * 2
                                        ctx.fillRect(80 - w / 2, y, w, 2)
                                    }
                                    ctx.fillRect(72, 96, 16, 10)
                                }
                                ctx.fillStyle = "white"
                                ctx.font = "bold 10px monospace"
                                ctx.fillText("HI " + (12000 + (cab.index * 3517)) , 4, 10)
                                if (Math.floor(f / 8) % 2 === 0)
                                    ctx.fillText("INSERT COIN", 46, 116)
                            }
                        }
                    }
                }
            }
            PointLight { // the screen's glow on the floor and the player
                position: Qt.vector3d(0, 128, 70)
                color: cab.modelData.hue
                brightness: 0.35
                quadraticFade: 3
            }
        }
    }

    // ------------------------------------------------ popcorn machine
    Node {
        position: Qt.vector3d(back.side * 0.68, 0, back.wallZ + 42)
        Box { // red cart
            color: "#c0201a"
            rough: 0.4
            position: Qt.vector3d(0, 45, 0)
            scale: Qt.vector3d(0.7, 0.9, 0.6)
        }
        Box { // glass case
            color: "#fff3c4"
            rough: 0.05
            position: Qt.vector3d(0, 120, 0)
            scale: Qt.vector3d(0.6, 0.6, 0.5)
        }
        Model { // popcorn heap, glowing warm under the heat lamp
            source: "#Sphere"
            position: Qt.vector3d(0, 100, 0)
            scale: Qt.vector3d(0.5, 0.22, 0.4)
            materials: PrincipledMaterial {
                baseColor: "#f6dc8a"
                emissiveFactor: Qt.vector3d(0.45, 0.33, 0.1)
                roughness: 0.9
            }
        }
        Box { // roof
            color: "#c0201a"
            position: Qt.vector3d(0, 155, 0)
            scale: Qt.vector3d(0.66, 0.08, 0.56)
        }
        Model { // printed sign on the roof
            source: "#Rectangle"
            position: Qt.vector3d(0, 172, 0)
            scale: Qt.vector3d(0.62, 0.16, 1)
            materials: PrincipledMaterial {
                roughness: 0.5
                baseColorMap: Texture {
                    sourceItem: Rectangle {
                        width: 400
                        height: 100
                        color: "#c0201a"
                        Text {
                            anchors.centerIn: parent
                            text: "POPCORN"
                            color: "#ffd21f"
                            font.weight: Font.Black
                            font.pixelSize: 72
                        }
                    }
                }
            }
        }
        PointLight {
            position: Qt.vector3d(0, 130, 40)
            color: "#ffb85c"
            brightness: 0.5
            quadraticFade: 3
        }
    }

    // ------------------------------------------------ the new releases wall
    // A wall rack of your latest watches, several copies of each, cover out
    // (the tapes themselves are drawn with all the others).
    Node {
        readonly property real x0: store.wallRack.x0 || 0
        readonly property real x1: store.wallRack.x1 || 0
        readonly property real len: x1 - x0
        id: rack
        position: Qt.vector3d((x0 + x1) / 2, 0, back.wallZ)
        Box { color: "#cfcabd"; rough: 0.8; position: Qt.vector3d(0, 104, 4); scale: Qt.vector3d(rack.len / 100, 1.98, 0.04) } // back board
        Repeater3D {
            model: 5
            Box {
                required property int index
                color: "#b7bbc0"
                metal: 0.4
                rough: 0.35
                position: Qt.vector3d(0, [168, 134, 100, 66, 32][index] - 1, 22)
                scale: Qt.vector3d(rack.len / 100, 0.02, 0.38)
            }
        }
        Repeater3D { // side panels
            model: 2
            Box {
                required property int index
                color: "#28469a"
                position: Qt.vector3d((index ? 1 : -1) * (rack.len / 2 + 2), 103, 22)
                scale: Qt.vector3d(0.04, 2.06, 0.42)
            }
        }
        Box { color: "#28469a"; position: Qt.vector3d(0, 8, 22); scale: Qt.vector3d(rack.len / 100 + 0.08, 0.16, 0.42) } // plinth
        Model { // header
            source: "#Rectangle"
            position: Qt.vector3d(0, 228, 6)
            scale: Qt.vector3d(rack.len / 100, 0.45, 1)
            materials: PrincipledMaterial {
                roughness: 0.5
                emissiveFactor: Qt.vector3d(0.25, 0.25, 0.25)
                baseColorMap: Texture { id: headerArt; sourceItem: headerItem }
                emissiveMap: headerArt
            }
        }
        Rectangle {
            id: headerItem
            visible: false
            width: Math.max(400, Math.round(rack.len * 2.5))
            height: 112
            color: "#1f3f99"
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 10; color: "#e3be2a" }
            Text {
                anchors.centerIn: parent
                text: "JUST RETURNED  ·  YOUR LATEST WATCHES"
                color: "#e3be2a"
                font.weight: Font.Black
                font.pixelSize: 60
                font.letterSpacing: 4
            }
        }
    }

    // ------------------------------------------------ staff door and the returns trolley
    Node {
        position: Qt.vector3d(-back.side * 0.6, 0, back.wallZ)
        Box { // frame
            color: "#3a3d45"
            position: Qt.vector3d(0, 108, 2)
            scale: Qt.vector3d(1.06, 2.16, 0.04)
        }
        Box { // door
            color: "#5c6068"
            rough: 0.5
            position: Qt.vector3d(0, 104, 3.5)
            scale: Qt.vector3d(0.94, 2.08, 0.03)
        }
        Box { // little window
            color: "#1b2030"
            rough: 0.1
            position: Qt.vector3d(0, 160, 5.2)
            scale: Qt.vector3d(0.3, 0.3, 0.005)
        }
        Box { // push plate
            color: "#c0c3c8"
            metal: 0.8
            rough: 0.3
            position: Qt.vector3d(34, 104, 5.4)
            scale: Qt.vector3d(0.1, 0.3, 0.005)
        }
        Node {
            position: Qt.vector3d(-32, 130, 5.4)
            scale: Qt.vector3d(0.12, 0.12, 0.12)
            Rectangle {
                width: 540
                height: 110
                color: "#c0201a"
                radius: 6
                Text {
                    anchors.centerIn: parent
                    text: "STAFF ONLY"
                    color: "white"
                    font.weight: Font.Black
                    font.pixelSize: 64
                    font.letterSpacing: 4
                }
            }
        }
        Model { // the light over the door
            source: "#Cube"
            position: Qt.vector3d(0, 228, 6)
            scale: Qt.vector3d(0.3, 0.06, 0.06)
            materials: PrincipledMaterial {
                baseColor: "#ffe9b8"
                emissiveFactor: Qt.vector3d(0.9, 0.8, 0.5)
                lighting: PrincipledMaterial.NoLighting
            }
        }

        // The trolley, a few tapes on each shelf.
        Node {
            position: Qt.vector3d(110, 0, 70)
            eulerRotation.y: 18
            Repeater3D {
                model: 2
                Box {
                    required property int index
                    color: "#9aa0a8"
                    metal: 0.7
                    rough: 0.35
                    position: Qt.vector3d(0, 28 + index * 42, 0)
                    scale: Qt.vector3d(0.8, 0.02, 0.45)
                }
            }
            Repeater3D { // corner posts
                model: 4
                Box {
                    required property int index
                    color: "#9aa0a8"
                    metal: 0.7
                    rough: 0.35
                    position: Qt.vector3d((index % 2 ? 1 : -1) * 38, 50, (index < 2 ? 1 : -1) * 20)
                    scale: Qt.vector3d(0.02, 1.0, 0.02)
                }
            }
            Repeater3D { // wheels
                model: 4
                Model {
                    required property int index
                    source: "#Cylinder"
                    position: Qt.vector3d((index % 2 ? 1 : -1) * 36, 4, (index < 2 ? 1 : -1) * 18)
                    eulerRotation.z: 90
                    scale: Qt.vector3d(0.07, 0.025, 0.07)
                    materials: PrincipledMaterial { baseColor: "#1b1b1b"; roughness: 0.8 }
                }
            }
            Repeater3D { // tapes standing on the shelves
                model: 12
                Box {
                    required property int index
                    readonly property int shelf: Math.floor(index / 6)
                    color: ["#141416", "#1d1d22", "#28469a", "#141416", "#7a1f1f", "#141416"][index % 6]
                    rough: 0.45
                    position: Qt.vector3d(-30 + (index % 6) * 12, 29 + shelf * 42 + 12, -4 + ((index * 5) % 7))
                    eulerRotation.y: ((index * 13) % 11) - 5
                    scale: Qt.vector3d(0.038, 0.24, 0.145)
                }
            }
        }
    }
}
