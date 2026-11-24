import QtQuick
import QtQuick3D

// Outside the shop: a night street of neon-signed buildings. Store3D draws it
// as ASCII. With `holdout`, only the solid shapes are drawn, invisibly: the
// clear shop layer uses that copy so buildings in front still hide the shop.
Node {
    id: street
    property bool holdout: false
    readonly property var store: shop.store
    readonly property Material invisible: CustomMaterial {
        shadingMode: CustomMaterial.Unshaded
        fragmentShader: "holdout.frag"
    }
    readonly property real front: store.frontZ
    readonly property real far: store.streetEndZ
    readonly property real half: store.streetHalfWidth

    // ------------------------------------------------------------ ground
    Node {
    visible: !street.holdout
    Model { // asphalt
        source: "#Rectangle"
        position: Qt.vector3d(0, -0.5, (street.front + street.far) / 2 + 400)
        eulerRotation.x: -90
        scale: Qt.vector3d(street.half * 2 / 100, (street.far - street.front + 800) / 100, 1)
        materials: PrincipledMaterial { baseColor: "#262a34"; roughness: 0.06; specularAmount: 1; metalness: 0.15 } // soaked
    }
    // Pavement slabs: their joints and a faint wet sheen keep the pavement
    // readable as ASCII characters all along the street.
    Texture {
        id: paving
        tilingModeHorizontal: Texture.Repeat
        tilingModeVertical: Texture.Repeat
        scaleU: street.half * 2 / 240
        scaleV: 400 / 240
        sourceItem: Canvas {
            width: 128
            height: 128
            onPaint: {
                const ctx = getContext("2d")
                ctx.fillStyle = "#8e929c"
                ctx.fillRect(0, 0, 128, 128)
                ctx.strokeStyle = "#2a2c32"
                ctx.lineWidth = 6
                ctx.strokeRect(0, 0, 128, 128)
                ctx.beginPath(); ctx.moveTo(64, 0); ctx.lineTo(64, 128); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(0, 64); ctx.lineTo(128, 64); ctx.stroke()
            }
        }
    }
    component Kerb: Model {
        source: "#Cube"
        materials: PrincipledMaterial {
            baseColorMap: paving
            emissiveMap: paving
            emissiveFactor: Qt.vector3d(0.34, 0.36, 0.42)
            roughness: 0.3
            specularAmount: 1
        }
    }
    Kerb { // pavement outside the shop (the part by the shop is drawn clear)
        position: Qt.vector3d(0, 5, street.front + 205)
        scale: Qt.vector3d(street.half * 2 / 100, 0.1, 4)
    }
    Kerb { // its kerb edge
        position: Qt.vector3d(0, 6, street.front + 408)
        scale: Qt.vector3d(street.half * 2 / 100, 0.12, 0.12)
    }
    Kerb { // pavement across the road
        position: Qt.vector3d(0, 5, street.far - 200)
        scale: Qt.vector3d(street.half * 2 / 100, 0.1, 4)
    }
    Repeater3D { // lane dashes
        model: Math.floor(street.half * 2 / 500)
        Model {
            required property int index
            source: "#Rectangle"
            position: Qt.vector3d(-street.half + 250 + index * 500, 0.3, (street.front + street.far) / 2)
            eulerRotation.x: -90
            scale: Qt.vector3d(2.2, 0.14, 1)
            materials: PrincipledMaterial {
                baseColor: "#e8c63a"
                emissiveFactor: Qt.vector3d(0.25, 0.2, 0.05)
            }
        }
    }
    }

    // ------------------------------------------------------------ buildings
    Texture {
        id: windows
        tilingModeHorizontal: Texture.Repeat
        tilingModeVertical: Texture.Repeat
        scaleU: 4
        scaleV: 9
        sourceItem: Canvas {
            width: 256
            height: 256
            onPaint: {
                const ctx = getContext("2d")
                ctx.fillStyle = "#000000"
                ctx.fillRect(0, 0, width, height)
                let seed = 42
                function rnd() { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646 }
                const lit = ["#ffd38a", "#ffe9b8", "#8af3ff", "#ff9ad5", "#c7b8ff"]
                for (let y = 0; y < 4; ++y) {
                    for (let x = 0; x < 4; ++x) {
                        if (rnd() < 0.45) continue
                        ctx.fillStyle = lit[Math.floor(rnd() * lit.length)]
                        ctx.globalAlpha = 0.45 + rnd() * 0.55
                        ctx.fillRect(x * 64 + 14, y * 64 + 12, 36, 40)
                    }
                }
            }
        }
    }

    Repeater3D {
        model: store.buildings
        Node {
            id: building
            required property var modelData
            readonly property var b: modelData
            readonly property real faceZ: b.z + b.facing * b.d / 2

            Model {
                source: "#Cube"
                position: Qt.vector3d(building.b.x, building.b.h / 2, building.b.z)
                scale: Qt.vector3d(building.b.w / 100, building.b.h / 100, building.b.d / 100)
                property PrincipledMaterial look: PrincipledMaterial {
                    baseColor: Qt.rgba(0.16 + building.b.tint * 0.08, 0.16, 0.22 + building.b.tint * 0.1, 1)
                    roughness: 0.8
                    emissiveMap: windows
                    emissiveFactor: Qt.vector3d(1.6, 1.6, 1.6)
                }
                materials: street.holdout ? [street.invisible] : [look]
            }
            // Neon sign on the street-facing side.
            Node {
                id: neonSign
                property real lit: 1
                visible: building.b.sign !== undefined && !street.holdout
                opacity: 0.35 + 0.65 * lit
                SequentialAnimation on lit {
                    running: neonSign.visible
                    loops: Animation.Infinite
                    PauseAnimation { duration: 2500 + (building.b.x * 7919 % 6000 + 6000) % 6000 }
                    NumberAnimation { to: 0.1; duration: 50 }
                    NumberAnimation { to: 1; duration: 60 }
                    NumberAnimation { to: 0.3; duration: 40 }
                    NumberAnimation { to: 1; duration: 120 }
                }
                position: Qt.vector3d(building.b.x - (building.b.vertical ? 55 : building.b.w * 0.375),
                                      building.b.signY + (building.b.vertical ? 650 : 140),
                                      building.faceZ + building.b.facing * 4)
                eulerRotation.y: building.b.facing > 0 ? 0 : 180
                scale: Qt.vector3d(0.5, 0.5, 0.5)
                Rectangle {
                    width: building.b.vertical ? 220 : building.b.w * 1.5
                    height: building.b.vertical ? 1300 : 280
                    color: Qt.rgba(Qt.color(building.b.neon || "white").r, Qt.color(building.b.neon || "white").g,
                                   Qt.color(building.b.neon || "white").b, 0.22)
                    border.color: building.b.neon || "white"
                    border.width: 12
                    radius: 18
                    Text {
                        anchors.fill: parent
                        anchors.margins: 10
                        text: building.b.vertical ? (building.b.sign || "").split("").join("\n") : (building.b.sign || "")
                        color: building.b.neon || "white"
                        style: Text.Outline
                        styleColor: "#ffffff"
                        font.family: Theme.display
                        font.weight: Font.Black
                        font.pixelSize: building.b.vertical ? 170 : 220
                        lineHeight: 0.95
                        fontSizeMode: Text.Fit
                        minimumPixelSize: 20
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ parked cars
    Repeater3D {
        model: store.cars
        Node {
            id: car
            required property var modelData
            position: Qt.vector3d(modelData.x, 0, modelData.z)
            component Part: Model {
                property color tint: "#333333"
                property real rough: 0.4
                property real glow: 0
                source: "#Cube"
                property PrincipledMaterial look: PrincipledMaterial {
                    baseColor: tint
                    roughness: rough
                    metalness: 0.3
                    emissiveFactor: Qt.vector3d(glow * tint.r, glow * tint.g, glow * tint.b)
                }
                materials: street.holdout ? [street.invisible] : [look]
            }
            Part { tint: car.modelData.color; rough: 0.25; position: Qt.vector3d(0, 50, 0); scale: Qt.vector3d(4.4, 0.62, 1.78) } // body
            Part { tint: car.modelData.color; rough: 0.25; position: Qt.vector3d(-20, 100, 0); scale: Qt.vector3d(2.4, 0.5, 1.6) } // cabin
            Part { tint: "#0d1018"; rough: 0.05; position: Qt.vector3d(-20, 102, 0); scale: Qt.vector3d(2.46, 0.38, 1.62) } // windows
            Part { tint: "#ff2a1a"; glow: 0.9; position: Qt.vector3d(-221, 58, 0); scale: Qt.vector3d(0.03, 0.1, 1.5) } // tail lights
            Part { tint: "#fff1cc"; glow: 0.25; position: Qt.vector3d(221, 54, 0); scale: Qt.vector3d(0.03, 0.08, 1.5) } // headlights
            Repeater3D {
                model: 4
                Model {
                    required property int index
                    source: "#Cylinder"
                    position: Qt.vector3d((index % 2 ? 1 : -1) * 140, 32, (index < 2 ? 1 : -1) * 84)
                    eulerRotation.x: 90
                    scale: Qt.vector3d(0.64, 0.2, 0.64)
                    property PrincipledMaterial look: PrincipledMaterial { baseColor: "#121212"; roughness: 0.8 }
                    materials: street.holdout ? [street.invisible] : [look]
                }
            }
        }
    }

    // ------------------------------------------------------------ street lamps
    Repeater3D {
        model: Math.floor(street.half * 2 / 900)
        Node {
            required property int index
            readonly property real lampX: -street.half + 450 + index * 900
            visible: Math.abs(lampX) > 400 // keep the doorway clear
            position: Qt.vector3d(lampX, 0, street.front + 360)
            Model {
                source: "#Cylinder"
                y: 230
                scale: Qt.vector3d(0.08, 4.6, 0.08)
                property PrincipledMaterial look: PrincipledMaterial { baseColor: "#2a2c33"; metalness: 0.6; roughness: 0.4 }
                materials: street.holdout ? [street.invisible] : [look]
            }
            Model {
                source: "#Sphere"
                y: 465
                scale: Qt.vector3d(0.32, 0.22, 0.32)
                property PrincipledMaterial look: PrincipledMaterial {
                    baseColor: "#ffd9a0"
                    emissiveFactor: Qt.vector3d(1, 0.85, 0.6)
                    lighting: PrincipledMaterial.NoLighting
                }
                materials: street.holdout ? [street.invisible] : [look]
            }
        }
    }
    // A few real lights: warm lamps by the shop, and neon spill.
    Repeater3D { // every street lamp lights its bit of pavement
        model: street.holdout ? 0 : Math.floor(street.half * 2 / 900)
        PointLight {
            required property int index
            readonly property real lampX: -street.half + 450 + index * 900
            visible: Math.abs(lampX) > 400
            position: Qt.vector3d(lampX, 455, street.front + 360)
            color: "#ffcf8a"
            brightness: 2.0
            quadraticFade: 0.6
        }
    }
    PointLight { visible: !street.holdout; position: Qt.vector3d(-1600, 600, street.far - 200); color: "#ff2bd6"; brightness: 2.5; quadraticFade: 0.4 }
    PointLight { visible: !street.holdout; position: Qt.vector3d(1600, 600, street.far - 200); color: "#2bf6ff"; brightness: 2.5; quadraticFade: 0.4 }
}
