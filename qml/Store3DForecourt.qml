import QtQuick
import QtQuick3D

// The pavement in front of the shop, drawn clear like the shop itself. It's
// wet all over, with darker, smoother damp patches where water collects; the
// real lights (street lamps, the sign's lamps) make the highlights on it. It
// runs past both ends of the shop and fades into the ASCII street's pavement.
Node {
    id: forecourt
    readonly property var store: shop.store
    readonly property real front: store.frontZ
    readonly property real halfW: store.halfWidth + 420 // past the shop, then fade
    readonly property real depth: 400
    property bool detail: true // relief and damp patches (off on Low)
    property bool beams: true  // visible light beams and pools (off on Low)
    property var lamps: []     // x of the street lamps near the shop

    // Colour: concrete slabs darkened by rain, with damp patches.
    Texture {
        id: slabs
        tilingModeHorizontal: Texture.Repeat
        tilingModeVertical: Texture.Repeat
        scaleU: forecourt.halfW * 2 / 240
        scaleV: forecourt.depth / 240
        sourceItem: Canvas {
            width: 256
            height: 256
            onPaint: {
                const ctx = getContext("2d")
                ctx.fillStyle = "#43464e"
                ctx.fillRect(0, 0, 256, 256)
                let seed = 5
                function rnd() { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646 }
                for (let i = 0; i < 2600; ++i) {
                    ctx.globalAlpha = 0.2 + rnd() * 0.4
                    ctx.fillStyle = ["#383b43", "#4d5058", "#3f424a"][Math.floor(rnd() * 3)]
                    ctx.fillRect(rnd() * 256, rnd() * 256, 2, 2)
                }
                // damp patches: soft, irregular, darker
                for (let i = 0; i < 14; ++i) {
                    const x = rnd() * 256, y = rnd() * 256, r = 14 + rnd() * 34
                    const g = ctx.createRadialGradient(x, y, 2, x, y, r)
                    g.addColorStop(0, "rgba(18,20,26,0.55)")
                    g.addColorStop(1, "rgba(18,20,26,0)")
                    ctx.globalAlpha = 1
                    ctx.fillStyle = g
                    ctx.fillRect(x - r, y - r, r * 2, r * 2)
                }
                ctx.globalAlpha = 0.9
                ctx.strokeStyle = "#24262c" // joints between slabs
                ctx.lineWidth = 3
                ctx.strokeRect(1, 1, 254, 254)
                ctx.beginPath(); ctx.moveTo(128, 0); ctx.lineTo(128, 256); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(0, 128); ctx.lineTo(256, 128); ctx.stroke()
            }
        }
    }
    // Roughness: the damp patches are almost mirror-smooth, the rest is
    // wet-satin. Same seed and layout as the colour, so they line up.
    Texture {
        id: wetness
        tilingModeHorizontal: Texture.Repeat
        tilingModeVertical: Texture.Repeat
        scaleU: forecourt.halfW * 2 / 240
        scaleV: forecourt.depth / 240
        sourceItem: Canvas {
            width: 256
            height: 256
            onPaint: {
                const ctx = getContext("2d")
                ctx.fillStyle = "rgb(110,110,110)"
                ctx.fillRect(0, 0, 256, 256)
                let seed = 5
                function rnd() { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646 }
                for (let i = 0; i < 2600; ++i) { rnd(); rnd(); rnd(); rnd(); rnd() } // keep in step with the colour
                for (let i = 0; i < 14; ++i) {
                    const x = rnd() * 256, y = rnd() * 256, r = 14 + rnd() * 34
                    const g = ctx.createRadialGradient(x, y, 2, x, y, r)
                    g.addColorStop(0, "rgba(8,8,8,1)")
                    g.addColorStop(1, "rgba(8,8,8,0)")
                    ctx.fillStyle = g
                    ctx.fillRect(x - r, y - r, r * 2, r * 2)
                }
            }
        }
    }
    Texture {
        id: slabBump
        tilingModeHorizontal: Texture.Repeat
        tilingModeVertical: Texture.Repeat
        scaleU: forecourt.halfW * 2 / 240
        scaleV: forecourt.depth / 240
        generateMipmaps: true
        mipFilter: Texture.Linear
        textureData: SurfaceDetail { kind: "tiles"; tiles: 2; strength: 6 }
    }
    // Fades the pavement out at both ends, into the ASCII street.
    Texture {
        id: endFade
        sourceItem: Canvas {
            width: 256
            height: 4
            onPaint: {
                const ctx = getContext("2d")
                const g = ctx.createLinearGradient(0, 0, 256, 0)
                const edge = 360 / (forecourt.halfW * 2) // the last 360 cm each side
                g.addColorStop(0, "rgba(255,255,255,0)")
                g.addColorStop(edge, "rgba(255,255,255,1)")
                g.addColorStop(1 - edge, "rgba(255,255,255,1)")
                g.addColorStop(1, "rgba(255,255,255,0)")
                ctx.fillStyle = g
                ctx.fillRect(0, 0, 256, 4)
            }
        }
    }

    Model { // the wet pavement
        source: "#Rectangle"
        position: Qt.vector3d(0, 10.3, forecourt.front + forecourt.depth / 2 + 5)
        eulerRotation.x: -90
        scale: Qt.vector3d(forecourt.halfW * 2 / 100, forecourt.depth / 100, 1)
        receivesShadows: false
        materials: PrincipledMaterial {
            baseColorMap: slabs
            roughnessMap: forecourt.detail ? wetness : null
            roughnessChannel: Material.R
            roughness: forecourt.detail ? 1.0 : 0.3 // scales the map
            specularAmount: 1
            normalMap: forecourt.detail ? slabBump : null
            normalStrength: 0.6
            opacityMap: endFade
            opacityChannel: Material.A
            alphaMode: PrincipledMaterial.Blend
        }
    }
    Model { // kerb edge at the road, fading the same way
        source: "#Cube"
        position: Qt.vector3d(0, 6, forecourt.front + forecourt.depth + 3)
        scale: Qt.vector3d(forecourt.halfW * 2 / 100, 0.12, 0.12)
        materials: PrincipledMaterial {
            baseColor: "#6a6d75"
            roughness: 0.25
            opacityMap: endFade
            opacityChannel: Material.A
            alphaMode: PrincipledMaterial.Blend
        }
    }

    // ------------------------------------------------ visible light
    // A beam of light falling through the rain from each lamp, brightest at
    // the top, and a pool where it lands on the wet ground.
    Texture { id: beamTex; textureData: GlowTexture { shape: "beam" } }
    Texture { id: poolTex; textureData: GlowTexture { shape: "pool" } }
    component Glow: Model {
        property color tint: "white"
        property real strength: 0.3
        property Texture map: poolTex
        source: "#Rectangle"
        castsShadows: false
        receivesShadows: false
        visible: forecourt.beams
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: Qt.rgba(tint.r, tint.g, tint.b, strength)
            baseColorMap: map
            alphaMode: PrincipledMaterial.Blend
            depthDrawMode: Material.NeverDepthDraw
            cullMode: Material.NoCulling
        }
    }
    // A beam is two crossed soft planes (reads as a cone from any side).
    component Beam: Node {
        id: beam
        property color tint: "#ffd59a"
        property real height: 440
        property real width: 220
        property real strength: 0.18
        Repeater3D {
            model: 2
            Glow {
                required property int index
                map: beamTex
                tint: beam.tint
                strength: beam.strength
                y: -beam.height / 2
                eulerRotation.y: index * 90
                scale: Qt.vector3d(beam.width / 100, beam.height / 100, 1)
            }
        }
    }

    Repeater3D { // street lamps
        model: forecourt.lamps
        Node {
            required property var modelData
            position: Qt.vector3d(modelData, 452, forecourt.front + 360)
            Beam { tint: "#ffcf8a"; height: 440; width: 280; strength: 0.4 }
            Glow { y: -440; eulerRotation.x: -90; tint: "#ffcf8a"; strength: 1.0; scale: Qt.vector3d(3.6, 3.6, 1) }
            Glow { eulerRotation.y: 0; tint: "#ffe2b0"; strength: 1.0; scale: Qt.vector3d(1.1, 1.1, 1) } // halo round the bulb
        }
    }
    Repeater3D { // canopy downlights
        model: 4
        Node {
            required property int index
            position: Qt.vector3d((index - 1.5) * (store.halfWidth * 0.55), 268, forecourt.front + 50)
            Beam { tint: "#fff1d8"; height: 256; width: 160; strength: 0.18 }
            Glow { y: -256; eulerRotation.x: -90; tint: "#fff1d8"; strength: 0.9; scale: Qt.vector3d(2.8, 2.4, 1) }
        }
    }
}
