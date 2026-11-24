import QtQuick
import QtQuick3D

// The inside of the shop: carpet, ceiling panels, walls with lit posters,
// shelving units with aisle signs, and the counter with its TV.
Node {
    id: interior
    // Dev aid: parts switched off with CINEFY_OFF (see main.cpp).
    function off(part) { return devOff !== "" && devOff.split(",").indexOf(part) >= 0 }
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
            base: "#2a468e"
            tones: ["#233c7a", "#31519e", "#1f3570", "#3a5aa8", "#2b4386"]
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
            base: "#e8b62c"
            tones: ["#dfad26", "#efc040", "#d6a420", "#e4b335"]
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
            base: "#efeee9"
            tones: ["#e4e2dc", "#f6f5f1", "#dcd9d1"]
            specks: 9000
            seed: 23
            extra: function(ctx, rnd) {
                // Fissures and pinholes of mineral-fibre tiles.
                ctx.strokeStyle = "#a9a69d"
                ctx.lineWidth = 1
                for (let i = 0; i < 900; ++i) {
                    ctx.globalAlpha = 0.25 + rnd() * 0.35
                    const x = rnd() * 512, y = rnd() * 512, a = rnd() * Math.PI, l = 2 + rnd() * 6
                    ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + Math.cos(a) * l, y + Math.sin(a) * l); ctx.stroke()
                }
                ctx.globalAlpha = 1
                ctx.fillStyle = "#c4c2bb"
                for (let i = 0; i <= 4; ++i) {
                    ctx.fillRect(i * 128 - 2, 0, 4, 512)
                    ctx.fillRect(0, i * 128 - 2, 512, 4)
                }
                for (let i = 0; i < 3; ++i) {
                    const x = Math.floor(rnd() * 4) * 128 + 20, y = Math.floor(rnd() * 4) * 128 + 20
                    const g = ctx.createRadialGradient(x + 40, y + 40, 5, x + 40, y + 40, 50)
                    g.addColorStop(0, "rgba(160,120,50,0.12)")
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
        // The light the floor, shelves and walls bounce back up keeps a
        // real shop's ceiling bright between the panels.
        materials: PrincipledMaterial {
            baseColorMap: ceilingTex
            roughness: 0.95
            normalMap: interior.detail ? ceilingBump : null
            normalStrength: 0.7
            emissiveMap: ceilingTex
            emissiveFactor: Qt.vector3d(0.22, 0.22, 0.22)
        }
    }
    // Fluorescent troffers. Not every tube is in good shape. They're drawn
    // instanced: one draw per part for the whole ceiling (frames, the
    // diffusers in three brightnesses, halos, floor pools), plus the one
    // tired tube that flickers, which is a normal model.
    readonly property int trofferCols: Math.max(1, Math.floor(interior.w / 300))
    readonly property int trofferRows: Math.max(1, Math.floor(interior.depth / 300))
    readonly property int flickerIndex: 9
    function trofferGlow(i) { return i % 11 === 4 ? 0.12 : i % 7 === 2 ? 0.75 : 1 }
    function trofferPos(i, y) {
        return Qt.vector3d(-interior.w / 2 + 150 + (i % trofferCols) * 300, y,
                           store.backZ + 150 + Math.floor(i / trofferCols) * 300)
    }
    // Entries for one part: `glow` picks the diffusers of one brightness
    // (undefined: all), the flickering tube is always left out.
    function trofferEntries(y, scale, rot, glow, alpha) {
        const out = []
        for (let i = 0; i < trofferCols * trofferRows; ++i) {
            if (i === flickerIndex || (glow !== undefined && trofferGlow(i) !== glow))
                continue
            const e = { p: trofferPos(i, y), s: scale, r: rot }
            if (alpha)
                e.c = Qt.rgba(1, 1, 1, trofferGlow(i))
            out.push(e)
        }
        return out
    }
    Node {
        visible: !interior.off("troffers")
        Model { // metal frames
            source: "#Cube"
            castsShadows: false
            receivesShadows: false
            instancing: ListInstancing {
                entries: interior.trofferEntries(interior.ceiling - 1, Qt.vector3d(1.28, 0.02, 0.68), Qt.vector3d(0, 0, 0))
            }
            materials: PrincipledMaterial { baseColor: "#b9b7b0"; metalness: 0.5; roughness: 0.4 }
        }
        Repeater3D { // diffusers, brighter than white so they bloom like real tubes
            model: [1, 0.75, 0.12]
            Model {
                required property real modelData
                source: "#Rectangle"
                castsShadows: false
                receivesShadows: false
                instancing: ListInstancing {
                    entries: interior.trofferEntries(interior.ceiling - 2.2, Qt.vector3d(1.2, 0.6, 1), Qt.vector3d(90, 0, 0), modelData)
                }
                materials: PrincipledMaterial {
                    baseColor: "#f4f6f8"
                    roughness: 0.4
                    emissiveFactor: Qt.vector3d(2.6 * modelData, 2.7 * modelData, 2.8 * modelData)
                }
            }
        }
        LightQuad { // halos on the ceiling round the panels
            visible: interior.lightPools > 0
            tint: "#eef3ff"
            strength: 0.9 * interior.lightPools
            instancing: ListInstancing {
                entries: interior.trofferEntries(interior.ceiling - 2.6, Qt.vector3d(2.6, 1.7, 1), Qt.vector3d(90, 0, 0), undefined, true)
            }
        }
        LightQuad { // pools of light on the floor below
            visible: interior.lightPools > 0
            tint: "#fff7e8"
            strength: 0.18 * interior.lightPools
            instancing: ListInstancing {
                entries: interior.trofferEntries(0.6, Qt.vector3d(3.4, 2.6, 1), Qt.vector3d(-90, 0, 0), undefined, true)
            }
        }
        Node { // the tired tube
            id: troffer
            property real flick: 1
            readonly property real glow: interior.trofferGlow(interior.flickerIndex) * flick
            visible: interior.trofferCols * interior.trofferRows > interior.flickerIndex
            SequentialAnimation on flick {
                running: troffer.visible
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
            position: interior.trofferPos(interior.flickerIndex, interior.ceiling - 1)
            Model {
                castsShadows: false
                source: "#Cube"
                scale: Qt.vector3d(1.28, 0.02, 0.68)
                materials: PrincipledMaterial { baseColor: "#b9b7b0"; metalness: 0.5; roughness: 0.4 }
            }
            Model {
                castsShadows: false
                source: "#Rectangle"
                y: -1.2
                eulerRotation.x: 90
                scale: Qt.vector3d(1.2, 0.6, 1)
                materials: PrincipledMaterial {
                    baseColor: "#f4f6f8"
                    roughness: 0.4
                    emissiveFactor: Qt.vector3d(2.6 * troffer.glow, 2.7 * troffer.glow, 2.8 * troffer.glow)
                }
            }
            LightQuad {
                y: -1.6
                eulerRotation.x: 90
                scale: Qt.vector3d(2.6, 1.7, 1)
                tint: "#eef3ff"
                strength: 0.9 * troffer.glow * interior.lightPools
                visible: interior.lightPools > 0
            }
            LightQuad {
                y: -(interior.ceiling - 1) + 0.6
                eulerRotation.x: -90
                scale: Qt.vector3d(3.4, 2.6, 1)
                tint: "#fff7e8"
                strength: 0.18 * troffer.glow * interior.lightPools
                visible: interior.lightPools > 0
            }
        }
    }

    // Air vents in the ceiling, between some of the light panels (instanced:
    // one draw for the plates, one for the louvres).
    readonly property var ventSpots: {
        const cols = Math.max(1, Math.floor(interior.w / 600)), rows = Math.max(1, Math.floor(interior.depth / 600))
        const out = []
        for (let i = 0; i < cols * rows; ++i)
            out.push(Qt.vector3d(-interior.w / 2 + 300 + (i % cols) * 600 + 150, interior.ceiling - 0.6,
                                 store.backZ + 300 + Math.floor(i / cols) * 600))
        return out
    }
    Node {
        visible: !interior.off("vents")
        Model { // grille plates
            source: "#Cube"
            castsShadows: false
            receivesShadows: false
            instancing: ListInstancing {
                entries: interior.ventSpots.map(p => ({ p: p, s: Qt.vector3d(0.58, 0.012, 0.58) }))
            }
            materials: PrincipledMaterial { baseColor: "#e3e2dd"; roughness: 0.5; metalness: 0.2 }
        }
        Model { // louvres, dark gaps between them
            source: "#Rectangle"
            castsShadows: false
            receivesShadows: false
            instancing: ListInstancing {
                entries: {
                    const out = []
                    for (const p of interior.ventSpots)
                        for (let k = 0; k < 5; ++k)
                            out.push({ p: Qt.vector3d(p.x, p.y - 0.8, p.z - 20 + k * 10), s: Qt.vector3d(0.44, 0.035, 1), r: Qt.vector3d(90, 0, 0) })
                    return out
                }
            }
            materials: PrincipledMaterial { baseColor: "#5d5d5a"; roughness: 0.8 }
        }
    }

    // ------------------------------------------------------------ walls
    component Wall: Model {
        id: wall
        property string bakeKey
        source: "#Rectangle"
        usedInBakedLighting: interior.bake
        bakedLightmap: BakedLightmap { enabled: interior.bake; key: wall.bakeKey }
        materials: PrincipledMaterial { baseColorMap: wallTex; roughness: 0.62; specularAmount: 0.6; normalMap: interior.detail ? plasterBump : null; normalStrength: 0.35 }
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
    // Blue stripe along the back wall, a scuffed skirting board along all three.
    Repeater3D {
        visible: !interior.off("walltrim")
        model: 4
        Model {
            required property int index
            readonly property int wall: index === 0 ? 0 : index - 1
            readonly property bool skirting: index >= 1
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
        visible: !interior.off("front")
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
        // Not where the wall racks stand.
        const free = (side, z) => !store.wallRacks.some(r => r.side === side && z > r.z0 - 140 && z < r.z1 + 140)
        for (let z = store.backZ + 230; z <= leftEnd; z += gap)
            if (free(-1, z)) spots.push({ side: -1, z: z })
        for (let z = store.backZ + 230 + gap / 2; z <= rightEnd; z += gap)
            if (free(1, z)) spots.push({ side: 1, z: z })
        spots.sort((a, b) => a.z - b.z) // alternate sides as the films go
        return spots.slice(0, shop.wallpapers.length)
    }
    Repeater3D {
        visible: !interior.off("posters")
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

    // The free-standing units: stepped chrome wire shelves on a beige
    // slatwall spine, stepped slatwall ends, a dark plinth. The wire and the
    // ends are one mesh each for the whole shop (see ShelvingGeometry).
    Texture {
        id: slatTex // slatwall: beige laminate with a groove every 7.6 cm
        tilingModeHorizontal: Texture.Repeat
        tilingModeVertical: Texture.Repeat
        generateMipmaps: true
        mipFilter: Texture.Linear
        sourceItem: Canvas {
            width: 256
            height: 256
            onPaint: {
                const ctx = getContext("2d")
                ctx.fillStyle = "#d6c6a1"
                ctx.fillRect(0, 0, 256, 256)
                let seed = 11
                function rnd() { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646 }
                for (let i = 0; i < 1800; ++i) { // laminate speckle
                    ctx.globalAlpha = 0.08 + rnd() * 0.1
                    ctx.fillStyle = rnd() < 0.5 ? "#b9a982" : "#e6d8b6"
                    ctx.fillRect(rnd() * 256, rnd() * 256, 2, 1)
                }
                ctx.globalAlpha = 1
                const step = 256 / 13
                for (let i = 0; i < 13; ++i) {
                    const y = Math.round(i * step)
                    ctx.fillStyle = "#6f6248" // the groove's shadow
                    ctx.fillRect(0, y, 256, 4)
                    ctx.fillStyle = "#f0e4c6" // its lit lower edge
                    ctx.fillRect(0, y + 4, 256, 1)
                }
            }
        }
    }
    Model {
        visible: !interior.off("wire")
        geometry: ShelvingGeometry { layout: store; part: "wire" }
        receivesShadows: false
        castsShadows: false // thin wires under a light straight above: shadows not worth the vertices
        materials: PrincipledMaterial { baseColor: "#cfd2d6"; metalness: 1; roughness: 0.3 }
    }
    Model {
        visible: !interior.off("ends")
        geometry: ShelvingGeometry { layout: store; part: "ends" }
        materials: PrincipledMaterial { baseColorMap: slatTex; roughness: 0.6; specularAmount: 0.4 }
    }
    Repeater3D {
        visible: !interior.off("plinths")
        model: store.gondolas
        Part { // plinth
            required property var modelData
            required property int index
            bakeKey: "u" + index + "-plinth"
            color: "#4a4a4c"
            position: Qt.vector3d(modelData.x, 5, modelData.z)
            scale: Qt.vector3d(0.92, 0.1, modelData.length / 100)
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
        visible: !interior.off("signs")
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
                materials: PrincipledMaterial { baseColor: "#e9e8e3"; roughness: 0.5 }
            }
            SignFace {
                z: 1.6
                w: sign.modelData.width
                h: 40
                glow: 0.12
                art: Rectangle {
                    width: Math.round(sign.modelData.width * 4)
                    height: 160
                    color: "#f6f5f1"
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
                        color: "#24408f"
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
        visible: !interior.off("endsigns")
        model: store.endSigns
        Node {
            id: endSign
            required property var modelData
            position: Qt.vector3d(modelData.x, 0, modelData.z)
            eulerRotation.y: modelData.yaw
            SignFace {
                position: Qt.vector3d(0, 166, 0.4)
                w: 40
                h: 62
                glow: 0.08
                art: Rectangle {
                    width: 240
                    height: 372
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
        visible: !interior.off("talkers")
        model: store.talkers
        Node {
            id: talker
            required property var modelData
            readonly property var film: shop.film(modelData.film)
            position: modelData.position
            eulerRotation: Qt.vector3d(0, modelData.yaw, (modelData.film % 7) - 3)
            // A printed card (a texture drawn once), not a live 2D item:
            // 60 of those cost a 2D render each, every frame.
            SignFace {
                position: Qt.vector3d(0, 0.16, 0.2)
                w: 12
                h: 7.68
                glow: 0.04
                art: Rectangle {
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
        visible: !interior.off("candy")
        position: store.candyRack
        Model {
            source: "#Cube"
            y: 70
            scale: Qt.vector3d(0.7, 1.4, 0.45)
            materials: PrincipledMaterial { baseColor: "#cfcabd"; roughness: 0.7 }
        }
        Model { // the sweets: one instanced draw, coloured per packet
            source: "#Cube"
            castsShadows: false
            instancing: ListInstancing {
                entries: {
                    const colours = ["#e6332a", "#e3be2a", "#2f5fd0", "#ff3d9a", "#39b54a", "#f08a24"]
                    const out = []
                    for (let i = 0; i < 24; ++i)
                        out.push({ p: Qt.vector3d(-26 + (i % 6) * 10.5, 30 + Math.floor(i / 6) * 30, 24),
                                   s: Qt.vector3d(0.08, 0.12, 0.04), c: colours[(i * 5) % 6] })
                    return out
                }
            }
            materials: PrincipledMaterial { baseColor: "white"; roughness: 0.4 }
        }
    }

    // Banners hanging from the ceiling.
    Repeater3D {
        visible: !interior.off("banners")
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
                    SignFace { // a printed banner, centred on the rod
                        position: Qt.vector3d(0, -18.75, 0.6)
                        w: 275
                        h: 37.5
                        glow: 0.3
                        art: Rectangle {
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
        visible: shop.mostWatched.length > 0 && !interior.off("hall")
        Repeater3D { // the title in raised gold letters: a dark shadow layer, then the letters
            model: 2
            Model {
                required property int index
                source: "#Rectangle"
                castsShadows: false
                position: Qt.vector3d(index === 0 ? 1.2 : 0, 307 - (index === 0 ? 1.2 : 0), index === 0 ? 0.6 : 2)
                scale: Qt.vector3d(4.2, 0.4, 1)
                materials: PrincipledMaterial {
                    roughness: 0.35
                    metalness: index === 0 ? 0 : 0.3
                    alphaMode: PrincipledMaterial.Blend
                    // a little backlight, so the gold reads as gold, not brown
                    emissiveMap: index === 0 ? null : hallLetters
                    emissiveFactor: Qt.vector3d(0.45, 0.45, 0.45)
                    baseColorMap: Texture {
                        id: hallLetters
                        generateMipmaps: true
                        mipFilter: Texture.Linear
                        textureData: LetteringTexture {
                            text: "MOST RENTED OF ALL TIME"
                            color: index === 0 ? "#5a3c00" : "#ffb300"
                            pixelWidth: 1680
                            pixelHeight: 160
                        }
                    }
                }
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
                SignFace { // "RENTED ×3" plaque
                    position: Qt.vector3d(0, -68, 1)
                    w: 60
                    h: 16
                    glow: 0.2
                    art: Rectangle {
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

    // TVs hung from the ceiling in clusters of 2 or 4, back to back on one
    // pole, each playing its own rotation of film backdrops.
    component TvCluster: Node {
        id: cluster
        property int count: 2
        property int offset: 0
        readonly property real reach: count > 2 ? 60 : 28 // TV centre from the pole
        readonly property real hang: 268                  // top of the sets
        Model { // pole from the ceiling
            source: "#Cylinder"
            castsShadows: false
            position: Qt.vector3d(0, (interior.ceiling + cluster.hang) / 2, 0)
            scale: Qt.vector3d(0.05, (interior.ceiling - cluster.hang) / 100, 0.05)
            materials: PrincipledMaterial { baseColor: "#2a2a2c"; metalness: 0.6; roughness: 0.4 }
        }
        Repeater3D {
            model: cluster.count
            Node {
                id: arm
                required property int index
                eulerRotation.y: index * 360 / cluster.count
                Model { // arm out to the set
                    source: "#Cube"
                    castsShadows: false
                    position: Qt.vector3d(0, cluster.hang, cluster.reach / 2)
                    scale: Qt.vector3d(0.05, 0.04, cluster.reach / 100)
                    materials: PrincipledMaterial { baseColor: "#2a2a2c"; metalness: 0.6; roughness: 0.4 }
                }
                Node {
                    position: Qt.vector3d(0, cluster.hang - 28, cluster.reach)
                    eulerRotation.x: 10 // tilted down towards you
                    Model { // the set
                        source: "#Cube"
                        scale: Qt.vector3d(0.66, 0.52, 0.5)
                        materials: PrincipledMaterial { baseColor: "#1e1e21"; roughness: 0.45 }
                    }
                    Model { // screen
                        source: "#Rectangle"
                        position: Qt.vector3d(-4, -2, 25.2)
                        scale: Qt.vector3d(0.5, 0.38, 1)
                        materials: PrincipledMaterial {
                            lighting: PrincipledMaterial.NoLighting
                            baseColorMap: Texture {
                                sourceItem: Image {
                                    id: picture
                                    property int n: cluster.offset + arm.index * 7
                                    width: 320
                                    height: 240
                                    source: shop.wallpapers.length > 0 ? shop.wallpapers[n % shop.wallpapers.length] : ""
                                    sourceSize.width: 320
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    Timer {
                                        interval: 6000 + arm.index * 700 + cluster.offset * 113
                                        running: true
                                        repeat: true
                                        onTriggered: picture.n++
                                    }
                                }
                            }
                        }
                    }
                    Model { // power light
                        source: "#Rectangle"
                        position: Qt.vector3d(26, -22, 25.3)
                        scale: Qt.vector3d(0.015, 0.015, 1)
                        materials: PrincipledMaterial { baseColor: "#ff3b2f"; lighting: PrincipledMaterial.NoLighting }
                    }
                }
            }
        }
    }
    // Over the open aisles, never over a unit (the sets hang below its signs).
    readonly property var aisleXs: {
        const xs = [...new Set(store.gondolas.map(g => Math.round(g.x)))].sort((a, b) => a - b)
        const mids = []
        for (let i = 0; i + 1 < xs.length; ++i)
            mids.push((xs[i] + xs[i + 1]) / 2)
        return mids.length ? mids : [0]
    }
    TvCluster { // by the entrance
        visible: !interior.off("tvs")
        count: 4
        offset: 0
        position: Qt.vector3d(-store.halfWidth * 0.4, 0, store.frontZ * 0.55)
        eulerRotation.y: 20
    }
    TvCluster { // over a middle aisle, facing up and down it
        visible: !interior.off("tvs")
        count: 2
        offset: 3
        position: Qt.vector3d(interior.aisleXs[0], 0, store.backZ * 0.35)
    }
    TvCluster { // in the cross aisle at the back
        visible: !interior.off("tvs")
        count: 4
        offset: 9
        position: Qt.vector3d(interior.aisleXs[interior.aisleXs.length - 1], 0, store.backZ + 190)
        eulerRotation.y: 45
    }

    // ------------------------------------------------------------ counter
    Node {
        visible: !interior.off("counter")
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
