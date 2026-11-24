import QtQuick
import QtQuick3D
import Cinefy

// Tall racks along the side walls, like a real rental shop's wall of tapes:
// black uprights in 1 m bays, six angled black shelves with white price
// lips, a header of white letter tiles ("E V E R Y  T A P E ...") along the
// top, and the aisle's name in big raised letters on the yellow wall above.
//
// Each rack is built in its own frame: X runs along the rack in reading
// order (left to right as you face it), Z comes out of the wall, Y is up.
Node {
    id: racks
    readonly property var store: shop.store
    property bool bake: false

    component Box: Model {
        property color color: "#1b1b1d"
        property real rough: 0.55
        property real metal: 0
        source: "#Cube"
        castsShadows: false // against the wall: the light from above casts nothing worth a pass
        materials: PrincipledMaterial { baseColor: color; roughness: rough; metalness: metal }
    }

    Repeater3D {
        model: store.wallRacks
        Node {
            id: rack
            required property var modelData
            readonly property real len: modelData.z1 - modelData.z0
            readonly property int bays: modelData.bays
            readonly property real depth: modelData.depth
            readonly property real bayLen: len / Math.max(1, bays)
            readonly property real top: 236
            position: Qt.vector3d(modelData.x, 0, (modelData.z0 + modelData.z1) / 2)
            eulerRotation.y: -modelData.side * 90

            Box { // back panel
                color: "#232326"
                rough: 0.7
                position: Qt.vector3d(0, rack.top / 2, 3)
                scale: Qt.vector3d(rack.len / 100, rack.top / 100, 0.06)
            }
            Box { // kick plate
                color: "#2c2c2f"
                position: Qt.vector3d(0, 7, rack.depth / 2)
                scale: Qt.vector3d(rack.len / 100, 0.14, rack.depth / 100)
            }
            Repeater3D { // uprights between the bays
                model: rack.bays + 1
                Box {
                    required property int index
                    color: "#121214"
                    rough: 0.4
                    metal: 0.3
                    position: Qt.vector3d(-rack.len / 2 + index * rack.bayLen, rack.top / 2, rack.depth / 2)
                    scale: Qt.vector3d(0.025, rack.top / 100, rack.depth / 100)
                }
            }
            Repeater3D { // six angled shelves, white lip at the front
                model: 6
                Node {
                    required property int index
                    readonly property real level: 202 - 34 * index
                    Box {
                        color: "#1e1e21"
                        rough: 0.45
                        metal: 0.2
                        position: Qt.vector3d(0, level - 1, 24)
                        eulerRotation.x: -8
                        scale: Qt.vector3d(rack.len / 100, 0.02, 0.38)
                    }
                    Box {
                        color: "#f1f0ec"
                        rough: 0.45
                        position: Qt.vector3d(0, level + 2.6, rack.depth - 0.6)
                        scale: Qt.vector3d(rack.len / 100, 0.055, 0.012)
                    }
                }
            }
            Box { // top cap
                color: "#121214"
                position: Qt.vector3d(0, rack.top + 1, rack.depth / 2)
                scale: Qt.vector3d(rack.len / 100 + 0.02, 0.02, rack.depth / 100 + 0.02)
            }

            // Header: a row of white letter tiles, the title repeated along
            // the whole rack.
            Model {
                source: "#Rectangle"
                castsShadows: false
                position: Qt.vector3d(0, rack.top + 13, rack.depth - 2)
                eulerRotation.x: -6
                scale: Qt.vector3d(rack.len / 100, 0.24, 1)
                materials: PrincipledMaterial {
                    roughness: 0.5
                    baseColorMap: Texture {
                        id: tiles
                        readonly property string label: rack.modelData.title.toUpperCase()
                        readonly property int count: label.length + 3 // + star + 2 blanks
                        tilingModeHorizontal: Texture.Repeat
                        generateMipmaps: true
                        mipFilter: Texture.Linear
                        scaleU: rack.len / (count * 21)
                        sourceItem: Canvas {
                            width: tiles.count * 64
                            height: 72
                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.fillStyle = "#cfd2d8"
                                ctx.fillRect(0, 0, width, height)
                                for (let i = 0; i < tiles.count; ++i) {
                                    const x = i * 64
                                    ctx.fillStyle = "#fbfbf8"
                                    ctx.fillRect(x + 2, 2, 60, 68)
                                    const ch = i < tiles.label.length ? tiles.label[i] : i === tiles.label.length + 1 ? "★" : ""
                                    ctx.fillStyle = "#24408f"
                                    ctx.font = "900 46px sans-serif"
                                    ctx.textAlign = "center"
                                    ctx.textBaseline = "middle"
                                    ctx.fillText(ch, x + 32, 38)
                                }
                            }
                        }
                    }
                }
            }

            // Big raised letters on the wall above, and the shop's arrow sign,
            // at the start of the rack. They stand a few cm off the wall.
            Node {
                id: wallSign
                readonly property real signLen: Math.min(rack.len, 760)
                position: Qt.vector3d(-rack.len / 2 + signLen / 2, 297, 0)
                Model { // arrow plate
                    source: "#Rectangle"
                    position: Qt.vector3d(-wallSign.signLen / 2 + 72, 0, 3)
                    scale: Qt.vector3d(1.44, 0.6, 1)
                    materials: PrincipledMaterial {
                        roughness: 0.35
                        alphaMode: PrincipledMaterial.Blend
                        baseColorMap: Texture {
                            generateMipmaps: true
                            mipFilter: Texture.Linear
                            textureData: LetteringTexture {
                                kind: "arrow"
                                text: "CINEFY VIDEO"
                                color: "#f2c230"
                                plate: "#2741a0"
                                pixelWidth: 768
                                pixelHeight: 320
                            }
                        }
                    }
                }
                Repeater3D { // the name: a dark shadow layer, then the letters
                    model: 2
                    Model {
                        required property int index
                        source: "#Rectangle"
                        position: Qt.vector3d(80 + (index === 0 ? 1.5 : 0), index === 0 ? -1.5 : 0, index === 0 ? 1 : 4)
                        scale: Qt.vector3d((wallSign.signLen - 170) / 100, 0.62, 1)
                        materials: PrincipledMaterial {
                            roughness: 0.4
                            alphaMode: PrincipledMaterial.Blend
                            baseColorMap: Texture {
                                generateMipmaps: true
                                mipFilter: Texture.Linear
                                textureData: LetteringTexture {
                                    kind: "letters"
                                    text: rack.modelData.title.toLowerCase()
                                    color: index === 0 ? "#6b4c08" : "#2b3f97"
                                    pixelWidth: 1536
                                    pixelHeight: 192
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // A convex security mirror high in the back corner, like every shop had.
    Node {
        position: Qt.vector3d(-store.halfWidth + 34, 262, store.backZ + 34)
        eulerRotation: Qt.vector3d(14, 45, 0)
        Model {
            source: "#Sphere"
            scale: Qt.vector3d(0.5, 0.5, 0.16)
            materials: PrincipledMaterial { baseColor: "#e8ecef"; metalness: 1; roughness: 0.04 }
        }
        Model { // black rim
            source: "#Cylinder"
            eulerRotation.x: 90
            scale: Qt.vector3d(0.52, 0.03, 0.52)
            materials: PrincipledMaterial { baseColor: "#111113"; roughness: 0.5 }
        }
        Box { // bracket to the wall
            color: "#3a3a3d"
            position: Qt.vector3d(0, 0, -18)
            scale: Qt.vector3d(0.04, 0.04, 0.3)
        }
    }
}
