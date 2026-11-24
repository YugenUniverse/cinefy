import QtQuick
import QtQuick3D

// The inside of the shop: carpet, ceiling panels, walls with lit posters,
// shelving units with aisle signs, and the counter with its TV.
Node {
    id: interior
    readonly property var store: shop.store
    readonly property real w: store.halfWidth * 2
    readonly property real depth: store.frontZ - store.backZ
    readonly property real midZ: (store.frontZ + store.backZ) / 2
    readonly property real ceiling: 330
    property int radioStation: 0 // 0 off, 1..3 (set by Store3D)
    property bool bake: false     // use / produce baked lighting (set by Store3D)
    property bool detail: true    // surface relief (normal maps); off on Low

    // ------------------------------------------------ visible light
    // Soft additive quads: a halo round each ceiling panel and a pool of
    // light on the floor beneath it. They make the light itself visible.
    Texture { id: softRect; textureData: GlowTexture { shape: "rect" } }
    component LightQuad: Model {
        property color tint: "#fff6e6"
        property real strength: 0.3
        source: "#Rectangle"
        castsShadows: false
        receivesShadows: false
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: Qt.rgba(tint.r, tint.g, tint.b, strength)
            baseColorMap: softRect
            alphaMode: PrincipledMaterial.Blend
            depthDrawMode: Material.NeverDepthDraw
        }
    }
    property real lightPools: 1 // 0 on Low quality

    // ------------------------------------------------ surface relief
    // Normal maps tiled exactly like the colour textures they sit on.
    component Relief: Texture {
        property alias kind: gen.kind
        property alias strength: gen.strength
        property alias tiles: gen.tiles
        tilingModeHorizontal: Texture.Repeat
        tilingModeVertical: Texture.Repeat
        generateMipmaps: true
        mipFilter: Texture.Linear
        textureData: SurfaceDetail { id: gen }
    }
    Relief { id: carpetBump; kind: "carpet"; strength: 3; scaleU: interior.w / 260 * 3; scaleV: Math.max(1, -store.backZ) / 260 * 3 }
    Relief { id: linoBump; kind: "tiles"; tiles: 8; strength: 4; scaleU: interior.w / 240; scaleV: store.frontZ / 240 }
    Relief { id: plasterBump; kind: "plaster"; strength: 2.5; scaleU: 8; scaleV: 2 }
    Relief { id: ceilingBump; kind: "tiles"; tiles: 4; strength: 3; scaleU: interior.w / 240; scaleV: interior.depth / 240 }
    Relief { id: renderBump; kind: "plaster"; strength: 5; scaleU: 6; scaleV: 3 }
    Relief { id: baseTileBump; kind: "ceramic"; tiles: 8; strength: 5; scaleU: 6 }
    Relief { id: steelBump; kind: "brushed"; strength: 1.5 }

    // ------------------------------------------------------------ worn materials
    // Procedural textures so nothing is a flat, perfect colour.
    component Grime: Canvas {
        property string base: "#dddad0"
        property var tones: ["#cfcabd", "#e6e2d8", "#c8c2b2"]
        property int specks: 4000
        property int seed: 11
        property var extra: null // function(ctx, rnd) for details
        width: 512
        height: 512
        onPaint: {
            const ctx = getContext("2d")
            ctx.fillStyle = base
            ctx.fillRect(0, 0, width, height)
            let s = seed
            function rnd() { s = (s * 16807) % 2147483647; return (s - 1) / 2147483646 }
            // Soft blotches, then fine specks.
            for (let i = 0; i < 40; ++i) {
                ctx.globalAlpha = 0.05 + rnd() * 0.07
                ctx.fillStyle = tones[Math.floor(rnd() * tones.length)]
                ctx.beginPath()
                ctx.arc(rnd() * width, rnd() * height, 20 + rnd() * 90, 0, Math.PI * 2)
                ctx.fill()
            }
            for (let i = 0; i < specks; ++i) {
                ctx.globalAlpha = 0.2 + rnd() * 0.5
                ctx.fillStyle = tones[Math.floor(rnd() * tones.length)]
                ctx.fillRect(rnd() * width, rnd() * height, 1 + rnd() * 2, 1 + rnd() * 2)
            }
            ctx.globalAlpha = 1
            if (extra)
                extra(ctx, rnd)
        }
    }

    Texture {
        id: carpetTex
        tilingModeHorizontal: Texture.Repeat
        tilingModeVertical: Texture.Repeat
        scaleU: interior.w / 260
        scaleV: Math.max(1, -store.backZ) / 260
        sourceItem: Grime {
            base: "#3f4656"
            tones: ["#353b49", "#4c5466", "#2f3542", "#565e70", "#33415f"]
            specks: 14000
            seed: 7
        }
    }
    Texture {
        id: linoTex // checked linoleum by the door and the counter
        tilingModeHorizontal: Texture.Repeat
        tilingModeVertical: Texture.Repeat
        scaleU: interior.w / 240
        scaleV: store.frontZ / 240
        sourceItem: Grime {
            base: "#bdb6a4"
            tones: ["#a59d89", "#cbc5b4", "#968e7a"]
            specks: 2500
            seed: 3
            extra: function(ctx, rnd) {
                for (let y = 0; y < 8; ++y)
                    for (let x = 0; x < 8; ++x) {
                        if ((x + y) % 2 === 0)
                            continue
                        ctx.globalAlpha = 0.5 + rnd() * 0.15
                        ctx.fillStyle = "#4d5a6e"
                        ctx.fillRect(x * 64, y * 64, 64, 64)
                    }
                ctx.globalAlpha = 0.35
                ctx.strokeStyle = "#5c5546"
                for (let i = 0; i <= 8; ++i) {
                    ctx.beginPath(); ctx.moveTo(i * 64, 0); ctx.lineTo(i * 64, 512); ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(0, i * 64); ctx.lineTo(512, i * 64); ctx.stroke()
                }
                // Black scuffs from shoes.
                ctx.strokeStyle = "#222222"
                for (let i = 0; i < 30; ++i) {
                    ctx.globalAlpha = 0.15 + rnd() * 0.25
                    ctx.lineWidth = 1 + rnd() * 2
                    const x = rnd() * 512, y = rnd() * 512
                    ctx.beginPath(); ctx.moveTo(x, y); ctx.quadraticCurveTo(x + 10, y + 4, x + 8 + rnd() * 30, y + rnd() * 8); ctx.stroke()
                }
            }
        }
    }
    Texture {
        id: wallTex
        tilingModeHorizontal: Texture.Repeat
        tilingModeVertical: Texture.ClampToEdge
        scaleU: 4
        sourceItem: Grime {
            base: "#dcd7c9"
            tones: ["#cbc5b5", "#e4e0d5", "#bdb6a3", "#d2ccb9"]
            specks: 6000
            seed: 19
            extra: function(ctx, rnd) {
                // Scuffs and grime low down, where trolleys and shoes hit.
                const g = ctx.createLinearGradient(0, 380, 0, 512)
                g.addColorStop(0, "rgba(90,80,60,0)")
                g.addColorStop(1, "rgba(90,80,60,0.35)")
                ctx.fillStyle = g
                ctx.fillRect(0, 380, 512, 132)
                ctx.strokeStyle = "#6e6656"
                for (let i = 0; i < 25; ++i) {
                    ctx.globalAlpha = 0.15 + rnd() * 0.2
                    const x = rnd() * 512, y = 420 + rnd() * 80
                    ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + 6 + rnd() * 40, y + rnd() * 3); ctx.stroke()
                }
                // A few old tape marks from posters long gone.
                ctx.fillStyle = "#efe9d2"
                for (let i = 0; i < 6; ++i) {
                    ctx.globalAlpha = 0.5
                    ctx.fillRect(rnd() * 500, 120 + rnd() * 200, 14, 5)
                }
            }
        }
    }
    Texture {
        id: ceilingTex // acoustic tiles in a T-bar grid, a few water stains
        tilingModeHorizontal: Texture.Repeat
        tilingModeVertical: Texture.Repeat
        scaleU: interior.w / 240
        scaleV: interior.depth / 240
        sourceItem: Grime {
            base: "#e2dfd6"
            tones: ["#d4d0c5", "#ece9e1", "#c9c4b8"]
            specks: 9000
            seed: 23
            extra: function(ctx, rnd) {
                ctx.globalAlpha = 1
                ctx.fillStyle = "#9b978d"
                for (let i = 0; i <= 4; ++i) {
                    ctx.fillRect(i * 128 - 2, 0, 4, 512)
                    ctx.fillRect(0, i * 128 - 2, 512, 4)
                }
                for (let i = 0; i < 3; ++i) {
                    const x = Math.floor(rnd() * 4) * 128 + 20, y = Math.floor(rnd() * 4) * 128 + 20
                    const g = ctx.createRadialGradient(x + 40, y + 40, 5, x + 40, y + 40, 50)
                    g.addColorStop(0, "rgba(160,120,50,0.35)")
                    g.addColorStop(1, "rgba(160,120,50,0)")
                    ctx.fillStyle = g
                    ctx.fillRect(x - 20, y - 20, 120, 120)
                }
            }
        }
    }

    // ------------------------------------------------------------ floor & ceiling
    Model { // carpet in the aisles
        source: "#Rectangle"
        position: Qt.vector3d(0, 0, store.backZ / 2)
        eulerRotation.x: -90
        scale: Qt.vector3d(interior.w / 100, Math.max(1, -store.backZ) / 100, 1)
        usedInBakedLighting: interior.bake
        bakedLightmap: BakedLightmap { enabled: interior.bake; key: "carpet" }
        materials: PrincipledMaterial { baseColorMap: carpetTex; roughness: 1; normalMap: interior.detail ? carpetBump : null; normalStrength: 0.9 }
    }
    Model { // linoleum at the front
        source: "#Rectangle"
        position: Qt.vector3d(0, 0, store.frontZ / 2)
        eulerRotation.x: -90
        scale: Qt.vector3d(interior.w / 100, store.frontZ / 100, 1)
        usedInBakedLighting: interior.bake
        bakedLightmap: BakedLightmap { enabled: interior.bake; key: "lino" }
        materials: PrincipledMaterial { baseColorMap: linoTex; roughness: 0.32; specularAmount: 0.8; normalMap: interior.detail ? linoBump : null; normalStrength: 0.8 }
    }
    Model {
        source: "#Rectangle"
        position: Qt.vector3d(0, interior.ceiling, interior.midZ)
        eulerRotation.x: 90
        scale: Qt.vector3d(interior.w / 100, interior.depth / 100, 1)
        castsShadows: false
        materials: PrincipledMaterial { baseColorMap: ceilingTex; roughness: 0.95; normalMap: interior.detail ? ceilingBump : null; normalStrength: 0.7 }
    }
    // Fluorescent troffers. Not every tube is in good shape.
    Repeater3D {
        model: Math.max(1, Math.floor(interior.w / 300)) * Math.max(1, Math.floor(interior.depth / 300))
        Node {
            id: troffer
            required property int index
            readonly property int cols: Math.max(1, Math.floor(interior.w / 300))
            readonly property bool flickers: index === 9 // one tired tube
            readonly property real baseGlow: index % 11 === 4 ? 0.12 : index % 7 === 2 ? 0.75 : 1
            property real flick: 1
            readonly property real glow: baseGlow * flick
            SequentialAnimation on flick {
                running: troffer.flickers
                loops: Animation.Infinite
                PauseAnimation { duration: 3200 }
                NumberAnimation { to: 0.15; duration: 40 }
                NumberAnimation { to: 1; duration: 60 }
                NumberAnimation { to: 0.3; duration: 50 }
                NumberAnimation { to: 1; duration: 90 }
                PauseAnimation { duration: 900 }
                NumberAnimation { to: 0.1; duration: 30 }
                NumberAnimation { to: 1; duration: 200 }
            }
            position: Qt.vector3d(-interior.w / 2 + 150 + (index % cols) * 300,
                                  interior.ceiling - 1,
                                  store.backZ + 150 + Math.floor(index / cols) * 300)
            Model { // metal frame
                castsShadows: false
                source: "#Cube"
                scale: Qt.vector3d(1.28, 0.02, 0.68)
                materials: PrincipledMaterial { baseColor: "#b9b7b0"; metalness: 0.5; roughness: 0.4 }
            }
            Model { // diffuser
                castsShadows: false
                source: "#Rectangle"
                y: -1.2
                eulerRotation.x: 90
                scale: Qt.vector3d(1.2, 0.6, 1)
                materials: PrincipledMaterial {
                    baseColor: Qt.rgba(0.93 * troffer.glow + 0.05, 0.96 * troffer.glow + 0.04, troffer.glow, 1)
                    emissiveFactor: Qt.vector3d(0.95 * troffer.glow, 0.98 * troffer.glow, troffer.glow)
                    lighting: PrincipledMaterial.NoLighting
                }
            }
            LightQuad { // halo on the ceiling around the panel
                y: -1.6
                eulerRotation.x: 90
                scale: Qt.vector3d(2.6, 1.7, 1)
                tint: "#eef3ff"
                strength: 0.9 * troffer.glow * interior.lightPools
                visible: interior.lightPools > 0
            }
            LightQuad { // pool of light on the floor below
                y: -(interior.ceiling - 1) + 0.6
                eulerRotation.x: -90
                scale: Qt.vector3d(3.4, 2.6, 1)
                tint: "#fff7e8"
                strength: 0.5 * troffer.glow * interior.lightPools
                visible: interior.lightPools > 0
            }
        }
    }

    // ------------------------------------------------------------ walls
    component Wall: Model {
        id: wall
        property string bakeKey
        source: "#Rectangle"
        usedInBakedLighting: interior.bake
        bakedLightmap: BakedLightmap { enabled: interior.bake; key: wall.bakeKey }
        materials: PrincipledMaterial { baseColorMap: wallTex; roughness: 0.88; normalMap: interior.detail ? plasterBump : null; normalStrength: 0.6 }
    }
    Wall { // back
        bakeKey: "wall-back"
        position: Qt.vector3d(0, interior.ceiling / 2, store.backZ)
        scale: Qt.vector3d(interior.w / 100, interior.ceiling / 100, 1)
    }
    Wall { // left
        bakeKey: "wall-left"
        position: Qt.vector3d(-store.halfWidth, interior.ceiling / 2, interior.midZ)
        eulerRotation.y: 90
        scale: Qt.vector3d(interior.depth / 100, interior.ceiling / 100, 1)
    }
    Wall { // right
        bakeKey: "wall-right"
        position: Qt.vector3d(store.halfWidth, interior.ceiling / 2, interior.midZ)
        eulerRotation.y: -90
        scale: Qt.vector3d(interior.depth / 100, interior.ceiling / 100, 1)
    }
    // Faded blue stripe and a scuffed skirting board along the walls.
    Repeater3D {
        model: 6
        Model {
            required property int index
            readonly property int wall: index % 3
            readonly property bool skirting: index >= 3
            source: "#Rectangle"
            position: wall === 0 ? Qt.vector3d(0, skirting ? 6 : 250, store.backZ + 1)
                    : Qt.vector3d((wall === 1 ? -1 : 1) * (store.halfWidth - 1), skirting ? 6 : 250, interior.midZ)
            eulerRotation.y: wall === 0 ? 0 : wall === 1 ? 90 : -90
            scale: Qt.vector3d((wall === 0 ? interior.w : interior.depth) / 100, skirting ? 0.12 : 0.3, 1)
            materials: PrincipledMaterial { baseColor: skirting ? "#3b3a38" : "#2a4a96"; roughness: skirting ? 0.5 : 0.75 }
        }
    }

    // ------------------------------------------------------------ shop front with windows
    // Either side of the door: a low sill, a deep header, pillars and glass.
    Texture {
        id: facadeTex // painted render, streaked by years of rain
        tilingModeHorizontal: Texture.Repeat
        tilingModeVertical: Texture.Repeat
        scaleU: 3
        sourceItem: Grime {
            base: "#22325c"
            tones: ["#1b2849", "#2a3b69", "#18223f", "#2f416f"]
            specks: 7000
            seed: 31
            extra: function(ctx, rnd) {
                for (let i = 0; i < 60; ++i) { // dirty streaks running down
                    const x = rnd() * 512, len = 80 + rnd() * 300
                    const g = ctx.createLinearGradient(0, 0, 0, len)
                    g.addColorStop(0, "rgba(10,12,20,0.35)")
                    g.addColorStop(1, "rgba(10,12,20,0)")
                    ctx.fillStyle = g
                    ctx.fillRect(x, 0, 1 + rnd() * 4, len)
                }
            }
        }
    }
    Texture {
        id: tileTex // small dark tiles along the base
        tilingModeHorizontal: Texture.Repeat
        scaleU: 6
        sourceItem: Grime {
            base: "#3a3b3f"
            tones: ["#2e2f33", "#45464b", "#333438"]
            specks: 3000
            seed: 5
            extra: function(ctx, rnd) {
                ctx.strokeStyle = "#1c1c1e"
                ctx.lineWidth = 3
                ctx.globalAlpha = 0.9
                for (let i = 0; i <= 8; ++i) {
                    ctx.beginPath(); ctx.moveTo(i * 64, 0); ctx.lineTo(i * 64, 512); ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(0, i * 64); ctx.lineTo(512, i * 64); ctx.stroke()
                }
            }
        }
    }
    component FrontPiece: Model {
        id: frontPiece
        property string bakeKey
        source: "#Cube"
        usedInBakedLighting: interior.bake && bakeKey !== ""
        bakedLightmap: BakedLightmap { enabled: interior.bake && frontPiece.bakeKey !== ""; key: frontPiece.bakeKey }
        materials: PrincipledMaterial { baseColorMap: facadeTex; roughness: 0.75; normalMap: interior.detail ? renderBump : null; normalStrength: 0.9 }
    }
    component BasePiece: Model {
        id: basePiece
        property string bakeKey
        source: "#Cube"
        usedInBakedLighting: interior.bake && bakeKey !== ""
        bakedLightmap: BakedLightmap { enabled: interior.bake && basePiece.bakeKey !== ""; key: basePiece.bakeKey }
        materials: PrincipledMaterial { baseColorMap: tileTex; roughness: 0.3; specularAmount: 0.9; normalMap: interior.detail ? baseTileBump : null; normalStrength: 1 }
    }
    readonly property real paneSide: store.halfWidth - store.doorHalfWidth - 60 // glass width per side
    readonly property int panes: Math.max(1, Math.round(paneSide / 260))
    Repeater3D {
        model: 2
        Node {
            id: side
            required property int index
            readonly property int s: index === 0 ? -1 : 1
            readonly property real inner: store.doorHalfWidth          // edge at the door
            readonly property real outer: store.halfWidth              // edge at the side wall
            readonly property real span: outer - inner
            z: store.frontZ
            BasePiece { // tiled sill
                bakeKey: "front" + side.index + "-sill"
                position: Qt.vector3d(side.s * (side.inner + side.span / 2), 35, 0)
                scale: Qt.vector3d(side.span / 100, 0.7, 0.16)
            }
            FrontPiece { // header above the windows
                bakeKey: "front" + side.index + "-header"
                position: Qt.vector3d(side.s * (side.inner + side.span / 2), 350, 0)
                scale: Qt.vector3d(side.span / 100, 2.2, 0.14)
            }
            FrontPiece { // pillar by the door
                bakeKey: "front" + side.index + "-pillar-door"
                position: Qt.vector3d(side.s * (side.inner + 15), 155, 0)
                scale: Qt.vector3d(0.3, 1.7, 0.16)
            }
            FrontPiece { // pillar by the side wall
                bakeKey: "front" + side.index + "-pillar-wall"
                position: Qt.vector3d(side.s * (side.outer - 15), 155, 0)
                scale: Qt.vector3d(0.3, 1.7, 0.16)
            }
            Repeater3D { // mullions between panes
                model: interior.panes - 1
                FrontPiece {
                    required property int index
                    position: Qt.vector3d(side.s * (side.inner + 30 + (index + 1) * interior.paneSide / interior.panes), 155, 0)
                    scale: Qt.vector3d(0.08, 1.7, 0.12)
                }
            }
            Model { // the glass
                source: "#Rectangle"
                position: Qt.vector3d(side.s * (side.inner + side.span / 2), 155, 0)
                scale: Qt.vector3d((side.span - 60) / 100, 1.7, 1)
                materials: PrincipledMaterial {
                    baseColor: "#a9c7d6"
                    opacity: 0.14
                    alphaMode: PrincipledMaterial.Blend
                    roughness: 0.04
                    specularAmount: 1
                    cullMode: Material.NoCulling
                }
            }
        }
    }
    FrontPiece { // above the door
        bakeKey: "front-door-head"
        position: Qt.vector3d(0, 350, store.frontZ)
        scale: Qt.vector3d(store.doorHalfWidth * 2 / 100, 2.2, 0.14)
    }

    // Lit posters of your favourite films along the side walls.
    // Evenly along both side walls; the right wall stops before the counter
    // and the hall of fame. One backdrop per spot, as many as you have.
    readonly property var posterSpots: {
        const spots = []
        const gap = 330
        const leftEnd = store.frontZ - 180, rightEnd = store.counter.z - 300
        for (let z = store.backZ + 230; z <= leftEnd; z += gap)
            spots.push({ side: -1, z: z })
        for (let z = store.backZ + 230 + gap / 2; z <= rightEnd; z += gap)
            spots.push({ side: 1, z: z })
        spots.sort((a, b) => a.z - b.z) // alternate sides as the films go
        return spots.slice(0, shop.wallpapers.length)
    }
    Repeater3D {
        model: interior.posterSpots
        Node {
            required property var modelData
            required property int index
            readonly property int side: modelData.side
            position: Qt.vector3d(side * (store.halfWidth - 3), 175, modelData.z)
            eulerRotation.y: side < 0 ? 90 : -90
            Model {
                source: "#Cube"
                scale: Qt.vector3d(2.5, 1.45, 0.04)
                materials: PrincipledMaterial { baseColor: "#111111"; roughness: 0.4 }
            }
            Model {
                source: "#Rectangle"
                z: 2.5
                scale: Qt.vector3d(2.35, 1.32, 1)
                materials: PrincipledMaterial {
                    lighting: PrincipledMaterial.NoLighting
                    baseColorMap: Texture {
                        sourceItem: Image {
                            width: 640
                            height: 360
                            source: shop.wallpapers[index] || ""
                            sourceSize.width: 640
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ shelving units
    component Part: Model {
        id: part
        property color color: "#cccccc"
        property real rough: 0.6
        property real metal: 0
        property string bakeKey // empty: lit live only
        source: "#Cube"
        usedInBakedLighting: interior.bake && bakeKey !== ""
        bakedLightmap: BakedLightmap { enabled: interior.bake && part.bakeKey !== ""; key: part.bakeKey }
        materials: PrincipledMaterial {
            baseColor: part.color
            roughness: part.rough
            metalness: part.metal
            // metal parts (shelves) get a brushed-steel grain
            normalMap: interior.detail && part.metal > 0 ? steelBump : null
            normalStrength: 0.5
        }
    }

    Repeater3D {
        model: store.gondolas
        Node {
            id: unit
            required property var modelData
            required property int index
            readonly property string k: "u" + index
            readonly property real len: modelData.length
            x: modelData.x
            z: modelData.z

            Part { // plinth
                bakeKey: unit.k + "-plinth"
                color: "#28469a"
                y: 8
                scale: Qt.vector3d(0.74, 0.16, unit.len / 100)
            }
            Part { // pegboard spine
                bakeKey: unit.k + "-spine"
                color: "#cfcabd"
                rough: 0.9
                y: 104
                scale: Qt.vector3d(0.06, 1.92, unit.len / 100)
            }
            Repeater3D { // five shelves on each side
                model: 10
                Node {
                    required property int index
                    readonly property int side: index % 2 === 0 ? -1 : 1
                    readonly property real level: [168, 134, 100, 66, 32][Math.floor(index / 2)]
                    Part {
                        color: "#b7bbc0"
                        rough: 0.35
                        metal: 0.4
                        position: Qt.vector3d(side * 19, level - 1, 0)
                        scale: Qt.vector3d(0.32, 0.02, unit.len / 100)
                    }
                    Part { // price channel along the front edge
                        color: "#28469a"
                        position: Qt.vector3d(side * 35, level - 2, 0)
                        scale: Qt.vector3d(0.015, 0.05, unit.len / 100)
                    }
                }
            }
            Part { // top cap
                bakeKey: unit.k + "-cap"
                color: "#e3be2a"
                rough: 0.5
                y: 203
                scale: Qt.vector3d(0.76, 0.05, unit.len / 100 + 0.04)
            }
            Repeater3D { // end panels
                model: 2
                Part {
                    required property int index
                    bakeKey: unit.k + "-end" + index
                    color: "#28469a"
                    position: Qt.vector3d(0, 103, (index === 0 ? -1 : 1) * (unit.len / 2 + 2))
                    scale: Qt.vector3d(0.76, 2.06, 0.04)
                }
            }
        }
    }

    // A printed sign face: the 2D artwork is a texture on a real, lit surface
    // (not floating 2D text), so it takes the room's light like the rest of
    // the shop and only glows faintly, like a backlit panel.
    component SignFace: Model {
        id: face
        property Item art
        property real w: 100
        property real h: 40
        property real glow: 0.25
        source: "#Rectangle"
        castsShadows: false
        scale: Qt.vector3d(w / 100, h / 100, 1)
        Texture { id: artTex; sourceItem: face.art; generateMipmaps: true; mipFilter: Texture.Linear }
        materials: PrincipledMaterial {
            roughness: 0.55
            baseColorMap: artTex
            emissiveMap: artTex // one texture for both
            emissiveFactor: Qt.vector3d(face.glow, face.glow, face.glow)
        }
    }

    // Aisle header boards above each run of shelves.
    Repeater3D {
        model: store.signs
        Node {
            id: sign
            required property var modelData
            position: Qt.vector3d(modelData.x, 228, modelData.z)
            eulerRotation.y: modelData.yaw
            Model {
                castsShadows: false
                source: "#Cube"
                scale: Qt.vector3d(sign.modelData.width / 100, 0.4, 0.03)
                materials: PrincipledMaterial { baseColor: "#0e1430"; roughness: 0.6 }
            }
            SignFace {
                z: 1.6
                w: sign.modelData.width
                h: 40
                glow: 0.35
                art: Rectangle {
                    width: Math.round(sign.modelData.width * 4)
                    height: 160
                    color: "#0e1430"
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 14
                        color: sign.modelData.accent
                    }
                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -6
                        width: parent.width - 40
                        horizontalAlignment: Text.AlignHCenter
                        text: sign.modelData.title.toUpperCase()
                        color: sign.modelData.accent
                        font.family: Theme.display
                        font.weight: Font.Black
                        font.pixelSize: sign.modelData.first ? 96 : 70
                        font.letterSpacing: 6
                        wrapMode: Text.NoWrap
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: 12
                    }
                }
            }
        }
    }

    // Both ends of every unit carry its aisle name, on a printed card.
    Repeater3D {
        model: store.endSigns
        Node {
            id: endSign
            required property var modelData
            position: Qt.vector3d(modelData.x, 0, modelData.z)
            eulerRotation.y: modelData.yaw
            SignFace {
                position: Qt.vector3d(0, 196 - 45, 0.5)
                w: 68
                h: 90
                glow: 0.08
                art: Rectangle {
                    width: 272
                    height: 360
                    radius: 10
                    color: "#f3eee0"
                    border.color: endSign.modelData.accent
                    border.width: 12
                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 40
                        spacing: 10
                        Text {
                            width: parent.width
                            height: 230
                            // Wrap only between words: hyphens are non-breaking.
                            text: endSign.modelData.title.toUpperCase().replace(/-/g, "\u2011")
                            color: "#28469a"
                            font.family: Theme.display
                            font.weight: Font.Black
                            font.pixelSize: 64
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            fontSizeMode: Text.Fit
                            minimumPixelSize: 20
                        }
                        Text {
                            width: parent.width
                            text: endSign.modelData.count + " tapes"
                            color: "#6b6b6b"
                            font.pixelSize: 26
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }

    // Handwritten "staff pick" cards hanging under 5-star and reviewed films.
    Repeater3D {
        model: store.talkers
        Node {
            id: talker
            required property var modelData
            readonly property var film: shop.film(modelData.film)
            position: modelData.position
            eulerRotation: Qt.vector3d(0, modelData.yaw, (modelData.film % 7) - 3)
            Node {
                position: Qt.vector3d(-6, 4, 0)
                scale: Qt.vector3d(0.08, 0.08, 0.08)
                Rectangle {
                    width: 150
                    height: 96
                    color: "#fff59d"
                    Text {
                        anchors.fill: parent
                        anchors.margins: 8
                        text: talker.film.reviews && talker.film.reviews.length > 0
                              ? "“" + talker.film.reviews[0].text + "”"
                              : "STAFF PICK!\n" + Theme.stars(talker.film.rating)
                        color: "#b3261e"
                        font.pixelSize: talker.film.reviews && talker.film.reviews.length > 0 ? 15 : 24
                        font.italic: true
                        font.weight: Font.Bold
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    // Candy and popcorn rack by the counter.
    Node {
        position: store.candyRack
        Model {
            source: "#Cube"
            y: 70
            scale: Qt.vector3d(0.7, 1.4, 0.45)
            materials: PrincipledMaterial { baseColor: "#cfcabd"; roughness: 0.7 }
        }
        Repeater3D {
            model: 24
            Model {
                required property int index
                source: "#Cube"
                position: Qt.vector3d(-26 + (index % 6) * 10.5, 30 + Math.floor(index / 6) * 30, 24)
                scale: Qt.vector3d(0.08, 0.12, 0.04)
                materials: PrincipledMaterial {
                    baseColor: ["#e6332a", "#e3be2a", "#2f5fd0", "#ff3d9a", "#39b54a", "#f08a24"][(index * 5) % 6]
                    roughness: 0.4
                }
            }
        }
    }

    // Banners hanging from the ceiling.
    Repeater3D {
        model: ["BE KIND · REWIND", "MOST RENTED THIS WAY →", "NEW RELEASES EVERY WEEK"]
        Node {
            id: banner
            required property string modelData
            required property int index
            position: Qt.vector3d((index - 1) * store.halfWidth * 0.55, 262, store.frontZ * 0.25)
            Model {
                castsShadows: false
                source: "#Cube"
                y: 34
                scale: Qt.vector3d(0.02, 0.6, 0.02)
                materials: PrincipledMaterial { baseColor: "#777777" }
            }
            // Printed on both sides, so it reads right from either direction.
            Repeater3D {
                model: 2
                Node {
                    required property int index
                    eulerRotation.y: index * 180
                    Node {
                        position: Qt.vector3d(-137.5, 0, 0.6) // centred on the rod
                        scale: Qt.vector3d(0.25, 0.25, 0.25)
                        Rectangle {
                            width: 1100
                            height: 150
                            color: banner.index === 1 ? "#e3be2a" : "#28469a"
                            border.color: banner.index === 1 ? "#28469a" : "#e3be2a"
                            border.width: 10
                            Text {
                                anchors.centerIn: parent
                                width: parent.width - 70
                                horizontalAlignment: Text.AlignHCenter
                                fontSizeMode: Text.HorizontalFit // never runs past the edges
                                minimumPixelSize: 30
                                text: banner.modelData
                                color: banner.index === 1 ? "#28469a" : "#e3be2a"
                                font.family: Theme.display
                                font.weight: Font.Black
                                font.pixelSize: 70
                            }
                        }
                    }
                }
            }
        }
    }


    // Hall of fame behind the counter: your most watched films ever.
    Node {
        position: Qt.vector3d(store.halfWidth - 2, 0, store.counter.z)
        eulerRotation.y: -90
        visible: shop.mostWatched.length > 0
        Node {
            position: Qt.vector3d(-210, 326, 0.5)
            scale: Qt.vector3d(0.25, 0.25, 0.25)
            Text {
                width: 1680
                text: "MOST RENTED OF ALL TIME"
                color: "#ffb300"
                style: Text.Outline
                styleColor: "#5a3c00"
                horizontalAlignment: Text.AlignHCenter
                font.family: Theme.display
                font.weight: Font.Black
                font.pixelSize: 110
                font.letterSpacing: 6
            }
        }
        Repeater3D {
            model: Math.min(10, shop.mostWatched.length)
            Node {
                id: fame
                required property int index
                readonly property var entry: shop.mostWatched[index]
                position: Qt.vector3d(-124 + (index % 5) * 62, index < 5 ? 260 : 184, 0)
                scale: Qt.vector3d(0.52, 0.52, 0.52)
                Model { // frame
                    source: "#Cube"
                    scale: Qt.vector3d(0.74, 1.08, 0.03)
                    materials: PrincipledMaterial { baseColor: "#ffb300"; metalness: 0.7; roughness: 0.3 }
                }
                Model {
                    source: "#Rectangle"
                    z: 1.8
                    scale: Qt.vector3d(0.66, 0.99, 1)
                    materials: PrincipledMaterial {
                        lighting: PrincipledMaterial.NoLighting
                        baseColorMap: Texture {
                            sourceItem: Image {
                                width: 240
                                height: 360
                                source: fame.entry ? fame.entry.poster : ""
                                sourceSize.width: 240
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }
                    }
                }
                Node { // "×3" plaque
                    position: Qt.vector3d(-30, -60, 1)
                    scale: Qt.vector3d(0.25, 0.25, 0.25)
                    Rectangle {
                        width: 240
                        height: 64
                        radius: 8
                        color: "#1a1206"
                        border.color: "#ffb300"
                        border.width: 4
                        Text {
                            anchors.centerIn: parent
                            text: fame.entry ? "RENTED ×" + fame.entry.count : ""
                            color: "#ffb300"
                            font.weight: Font.Black
                            font.pixelSize: 34
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ counter
    Node {
        position: store.counter
        Part { // desk
            bakeKey: "counter-desk"
            color: "#28469a"
            y: 52
            scale: Qt.vector3d(1.0, 1.04, 3.3)
        }
        Part { // worktop
            bakeKey: "counter-top"
            color: "#e2ddcf"
            rough: 0.4
            y: 106
            scale: Qt.vector3d(1.1, 0.05, 3.4)
        }
        Part { // yellow stripe facing the shop
            color: "#e3be2a"
            position: Qt.vector3d(-50.5, 80, 0)
            scale: Qt.vector3d(0.01, 0.12, 3.3)
        }
        Part { // till
            color: "#2a2a2e"
            position: Qt.vector3d(5, 122, 110)
            scale: Qt.vector3d(0.4, 0.28, 0.45)
        }
        // The clerk's radio, at the near end of the counter.
        Node {
            position: Qt.vector3d(0, 108, -135)
            eulerRotation.y: -90
            Part { // body
                color: "#3b3631"
                rough: 0.5
                y: 10
                scale: Qt.vector3d(0.34, 0.2, 0.14)
            }
            Model { // speaker grille
                source: "#Cylinder"
                position: Qt.vector3d(-8, 10, 7.2)
                eulerRotation.x: 90
                scale: Qt.vector3d(0.13, 0.005, 0.13)
                materials: PrincipledMaterial { baseColor: "#1a1816"; roughness: 0.9 }
            }
            Model { // tuning display, glowing amber when it's on
                source: "#Rectangle"
                position: Qt.vector3d(9, 13, 7.2)
                scale: Qt.vector3d(0.12, 0.05, 1)
                materials: PrincipledMaterial {
                    baseColor: interior.radioStation > 0 ? "#ffb347" : "#3a2a18"
                    emissiveFactor: interior.radioStation > 0 ? Qt.vector3d(1, 0.6, 0.2) : Qt.vector3d(0, 0, 0)
                    lighting: PrincipledMaterial.NoLighting
                }
            }
            Model { // needle: moves with the station
                source: "#Cube"
                position: Qt.vector3d(4 + interior.radioStation * 3, 13, 7.4)
                scale: Qt.vector3d(0.004, 0.05, 0.002)
                materials: PrincipledMaterial { baseColor: "#c0201a"; lighting: PrincipledMaterial.NoLighting }
            }
            Model { // knob
                source: "#Cylinder"
                position: Qt.vector3d(9, 5, 7.5)
                eulerRotation.x: 90
                scale: Qt.vector3d(0.04, 0.02, 0.04)
                materials: PrincipledMaterial { baseColor: "#c9c3b5"; metalness: 0.5; roughness: 0.4 }
            }
            Model { // antenna
                source: "#Cylinder"
                position: Qt.vector3d(12, 34, -3)
                eulerRotation.z: -20
                scale: Qt.vector3d(0.006, 0.42, 0.006)
                materials: PrincipledMaterial { baseColor: "#b9bcc2"; metalness: 0.8; roughness: 0.3 }
            }
        }
        Part { // tape rewinder, shaped like a little car
            color: "#c4202f"
            rough: 0.3
            position: Qt.vector3d(0, 113, 150)
            scale: Qt.vector3d(0.2, 0.09, 0.3)
        }
        // CRT TV playing film backdrops.
        Node {
            position: Qt.vector3d(0, 108, -70)
            eulerRotation.y: -90
            Part {
                color: "#2b2b30"
                rough: 0.5
                y: 22
                scale: Qt.vector3d(0.56, 0.44, 0.46)
            }
            Model {
                source: "#Rectangle"
                position: Qt.vector3d(-3, 23, 23.2)
                scale: Qt.vector3d(0.44, 0.33, 1)
                materials: PrincipledMaterial {
                    lighting: PrincipledMaterial.NoLighting
                    baseColorMap: Texture {
                        sourceItem: Image {
                            id: tvPicture
                            property int n: 0
                            width: 320
                            height: 240
                            source: shop.wallpapers.length > 0 ? shop.wallpapers[n % shop.wallpapers.length] : ""
                            sourceSize.width: 320
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            Timer {
                                interval: 6000
                                running: true
                                repeat: true
                                onTriggered: tvPicture.n++
                            }
                        }
                    }
                }
            }
        }
    }
}
