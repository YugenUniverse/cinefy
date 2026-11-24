import QtQuick
import QtQuick.Controls
import QtQuick3D
import QtQuick3D.Particles3D
import QtMultimedia
import Cinefy

// The 3D shop. You arrive on a neon street drawn in ASCII, walk in through the
// door, and browse a 90s video store with every tape face-out on the shelves.
Item {
    id: root
    objectName: "store3d"

    // Dev aid for the key test (CINEFY_KEYTEST): which panels are open now.
    function devState() {
        const open = []
        if (pauseMenu.visible) open.push("menu" + (pauseMenu.page !== "main" ? ":" + pauseMenu.page : ""))
        if (storeMap.visible) open.push("map")
        if (memberCard.visible) open.push("card")
        if (clerkDialog.visible) open.push("clerk")
        if (vhsCase.visible) open.push("case")
        if (reading) open.push("diary")
        return open.length ? open.join("+") : "none"
    }

    readonly property var store: shop.store
    readonly property real eye: store.eyeHeight

    // ---------------------------------------------------------------- baked lighting
    // Pre-computed ray-traced bounce light for the room (see LightBaker).
    property bool bakeReload: false
    readonly property bool bake: baker.supported && (baker.baking || (baker.enabled && baker.available)) && !bakeReload
    Binding { target: baker; property: "signature"; value: store.signature }
    function bakeLighting() { baker.bake(shopView) }
    Timer { id: bakeTimer; interval: 3000; onTriggered: root.bakeLighting() }
    Connections {
        target: baker
        // Pick up the freshly written lightmaps.
        function onFinished(ok) {
            root.bakeReload = true
            Qt.callLater(() => root.bakeReload = false)
        }
    }

    // ---------------------------------------------------------------- player
    QtObject {
        id: player
        property real x: store.entrance.x
        property real z: store.entrance.z
        property real yaw: 0      // degrees, 0 looks down -Z (towards the shop)
        property real pitch: -2
        property real bob: 0
        property bool forward: false
        property bool back: false
        property bool left: false
        property bool right: false
        property bool turnLeft: false
        property bool turnRight: false
        property bool run: false
        readonly property bool moving: forward || back || left || right
    }

    property int aimedTape: -1
    property int aimedFilm: -1
    property var aimedInfo: null
    property int markedTape: -1   // tape the clerk walked you to
    property string location: ""
    // Waking up: 0 at start (black, silent) → 1. The picture and every sound
    // follow it together, so the shop opens like opening your eyes.
    property real wake: devMute ? 1 : 0 // (test runs: awake at once)
    SequentialAnimation on wake {
        running: !devMute
        PauseAnimation { duration: 900 }
        NumberAnimation { to: 1; duration: 1100; easing.type: Easing.InOutQuad }
    }

    readonly property bool uiOpen: vhsCase.visible || clerkDialog.visible || memberCard.visible
                                   || storeMap.visible || pauseMenu.visible

    // ---------------------------------------------------------------- diary in hand
    // J raises the rental ledger in your hands; you can still look around.
    property bool reading: false
    property real diaryRaise: reading ? 1 : 0
    Behavior on diaryRaise { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
    property Item diaryPages: DiaryPages {}
    function openDiary() {
        if (uiOpen)
            return
        diaryPages.load()
        reading = true
        player.forward = player.back = player.left = player.right = player.run = false
        pickupSound.play()
        release() // the pointer is for the pages now
        // Preparing the pages can move keyboard focus; take it back so J / Esc work.
        Qt.callLater(() => keys.forceActiveFocus())
    }
    function closeDiary() {
        reading = false
        capture()
    }
    // Map a mouse position onto the held diary's pages (in page pixels).
    function diaryPoint(mx, my) {
        const hit = rainView.pick(mx, my)
        if (!hit || hit.objectHit !== heldDiary.pageModel)
            return null
        return Qt.point(hit.uvPosition.x * diaryPages.width, (1 - hit.uvPosition.y) * diaryPages.height)
    }

    // ---------------------------------------------------------------- the clerk
    property bool aimClerk: false
    property bool aimCard: false // your membership card, lying on the counter
    readonly property vector3d cardPos: Qt.vector3d(store.counter.x - 36, 109, store.counter.z + 48)
    function aimingAtBox(o, d, lo, hi, maxDist) {
        const oa = [o.x, o.y, o.z], da = [d.x, d.y, d.z]
        let t0 = 0, t1 = maxDist
        for (let a = 0; a < 3; ++a) {
            if (Math.abs(da[a]) < 1e-6) {
                if (oa[a] < lo[a] || oa[a] > hi[a]) return false
                continue
            }
            let near = (lo[a] - oa[a]) / da[a], far = (hi[a] - oa[a]) / da[a]
            if (near > far) [near, far] = [far, near]
            t0 = Math.max(t0, near)
            t1 = Math.min(t1, far)
            if (t0 > t1) return false
        }
        return true
    }

    Component.onCompleted: {
        Qt.callLater(capture)
        if (devBake)
            bakeTimer.start()
        const v = devStart.split(",").map(Number)
        if (v.length === 4) {
            player.x = v[0]; player.z = v[1]; player.yaw = v[2]; player.pitch = v[3]
        }
    }

    function forwardVector() {
        const y = player.yaw * Math.PI / 180, p = player.pitch * Math.PI / 180
        return Qt.vector3d(-Math.sin(y) * Math.cos(p), Math.sin(p), -Math.cos(y) * Math.cos(p))
    }

    function travelTo(v) {
        if (!v || v.x === undefined)
            return
        let yaw = v.yaw
        while (yaw - player.yaw > 180) yaw -= 360
        while (yaw - player.yaw < -180) yaw += 360
        travel.stop()
        travelX.to = v.x
        travelZ.to = v.z
        travelYaw.to = yaw
        travelPitch.to = v.pitch
        travel.start()
        markedTape = v.tape !== undefined ? v.tape : -1
    }

    // ---------------------------------------------------------------- radio
    // The clerk's radio on the counter: click it (or press E) to change station.
    property int radioStation: 1 // 0 off
    readonly property var stations: ["Off", "Lo-fi", "Synthwave", "Late-night jazz"]
    property bool aimRadio: false
    readonly property vector3d radioPos: Qt.vector3d(store.counter.x, 118, store.counter.z - 135)
    // Heard all over the shop (it's the shop's music), a bit louder at the
    // counter, and only faintly from the street.
    readonly property real radioLevel: 0.5 * (0.6 + 0.4 * Math.max(0, 1 - Math.hypot(player.x - radioPos.x, player.z - radioPos.z) / 900))
                                       * (1 - 0.85 * outdoors)
    function tuneRadio() {
        radioStation = (radioStation + 1) % stations.length
        tuneSound.play()
    }
    // Is the crosshair on the radio? (a ray against its box)
    function aimingAtRadio(o, d) {
        const lo = [radioPos.x - 15, radioPos.y - 14, radioPos.z - 20]
        const hi = [radioPos.x + 15, radioPos.y + 16, radioPos.z + 20]
        const oa = [o.x, o.y, o.z], da = [d.x, d.y, d.z]
        let t0 = 0, t1 = 240
        for (let a = 0; a < 3; ++a) {
            if (Math.abs(da[a]) < 1e-6) {
                if (oa[a] < lo[a] || oa[a] > hi[a]) return false
                continue
            }
            let near = (lo[a] - oa[a]) / da[a], far = (hi[a] - oa[a]) / da[a]
            if (near > far) [near, far] = [far, near]
            t0 = Math.max(t0, near)
            t1 = Math.min(t1, far)
            if (t0 > t1) return false
        }
        return true
    }
    Repeater {
        model: ["radio-lofi", "radio-synthwave", "radio-jazz"]
        Item {
            id: station
            required property string modelData
            required property int index
            SoundEffect { muted: root.muted;
                source: sounds.url(station.modelData)
                loops: SoundEffect.Infinite
                volume: root.volume * root.wake * (root.radioStation === station.index + 1 ? root.radioLevel : 0)
                Component.onCompleted: play()
            }
        }
    }
    SoundEffect { muted: root.muted; id: tuneSound; source: sounds.url("tune"); volume: root.volume * root.wake * (0.35) }

    function pickUp() {
        if (reading)
            return
        if (aimClerk) {
            clerkDialog.open()
            return
        }
        if (aimCard) {
            memberCard.open()
            return
        }
        if (aimRadio) {
            tuneRadio()
            return
        }
        if (aimedFilm >= 0) {
            pickupSound.play()
            vhsCase.show(aimedFilm)
        }
    }

    // ---------------------------------------------------------------- sound
    // 0 deep inside the shop .. 1 out on the street.
    readonly property real outdoors: Math.max(0, Math.min(1, (player.z - store.frontZ + 60) / 200))
    // Inside, the rain is louder near the door.
    readonly property real nearDoor: Math.max(0, 1 - Math.hypot(player.x, store.frontZ - player.z) / 900)
    // The automatic doors open while you're near them.
    readonly property bool nearEntrance: Math.abs(player.x) < 260 && Math.abs(player.z - store.frontZ) < 300
    property real doorOpen: nearEntrance ? 1 : 0
    Behavior on doorOpen { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }
    onNearEntranceChanged: if (nearEntrance) doorSound.play()

    SoundEffect { muted: root.muted;
        source: sounds.url("rain")
        loops: SoundEffect.Infinite
        volume: root.volume * root.wake * (0.22 * root.outdoors)
        Component.onCompleted: play()
    }
    SoundEffect { muted: root.muted;
        source: sounds.url("rain-muffled")
        loops: SoundEffect.Infinite
        volume: root.volume * root.wake * ((1 - root.outdoors) * (0.1 + 0.2 * root.nearDoor))
        Component.onCompleted: play()
    }
    SoundEffect { muted: root.muted;
        source: sounds.url("hum")
        loops: SoundEffect.Infinite
        volume: root.volume * root.wake * (0.07 * (1 - root.outdoors))
        Component.onCompleted: play()
    }
    SoundEffect { muted: root.muted; id: chime; source: sounds.url("chime"); volume: root.volume * root.wake * (0.45) }
    SoundEffect { muted: root.muted; id: doorSound; source: sounds.url("door"); volume: root.volume * root.wake * (0.15) }
    SoundEffect { muted: root.muted; id: pickupSound; source: sounds.url("pickup"); volume: root.volume * root.wake * (0.7) }

    ParallelAnimation {
        id: travel
        NumberAnimation { id: travelX; target: player; property: "x"; duration: 900; easing.type: Easing.InOutCubic }
        NumberAnimation { id: travelZ; target: player; property: "z"; duration: 900; easing.type: Easing.InOutCubic }
        NumberAnimation { id: travelYaw; target: player; property: "yaw"; duration: 900; easing.type: Easing.InOutCubic }
        NumberAnimation { id: travelPitch; target: player; property: "pitch"; duration: 900; easing.type: Easing.InOutCubic }
    }

    FrameAnimation {
        running: true
        onTriggered: {
            const dt = Math.min(frameTime, 0.05)
            if (!root.uiOpen && !travel.running && !root.reading) {
                if (player.turnLeft) player.yaw += 110 * dt
                if (player.turnRight) player.yaw -= 110 * dt
                if (root.captured && !pointer.canWarp) {
                    if (look.lastX < 40) player.yaw += 120 * dt
                    else if (look.lastX > look.width - 40) player.yaw -= 120 * dt
                }
                let f = (player.forward ? 1 : 0) - (player.back ? 1 : 0)
                let s = (player.right ? 1 : 0) - (player.left ? 1 : 0)
                if (f !== 0 || s !== 0) {
                    const len = Math.sqrt(f * f + s * s)
                    f /= len; s /= len
                    const speed = (player.run ? 850 : 420) * dt
                    const y = player.yaw * Math.PI / 180
                    const nx = player.x + (-Math.sin(y) * f + Math.cos(y) * s) * speed
                    const nz = player.z + (-Math.cos(y) * f - Math.sin(y) * s) * speed
                    const p = store.collide(Qt.vector3d(player.x, 0, player.z), Qt.vector3d(nx, 0, nz), 26)
                    if ((player.z > store.frontZ) !== (p.z > store.frontZ))
                        chime.play() // the bell over the door
                    player.x = p.x
                    player.z = p.z
                    player.bob += dt * (player.run ? 13 : 9)
                }
            }
            const eyePos = Qt.vector3d(player.x, root.eye, player.z)
            const tape = store.pick(eyePos, root.forwardVector(), 230)
            root.aimRadio = !root.reading && tape < 0 && root.aimingAtRadio(eyePos, root.forwardVector())
            const c = store.clerk
            const k = root.cardPos
            root.aimCard = !root.reading && tape < 0 && !root.aimRadio
                           && root.aimingAtBox(eyePos, root.forwardVector(), [k.x - 16, k.y - 4, k.z - 18], [k.x + 16, k.y + 8, k.z + 18], 280)
            root.aimClerk = !root.reading && tape < 0 && !root.aimRadio && !root.aimCard
                            && root.aimingAtBox(eyePos, root.forwardVector(), [c.x - 30, 85, c.z - 30], [c.x + 30, 190, c.z + 30], 320)
            if (tape !== root.aimedTape) {
                root.aimedTape = tape
                const film = store.filmOfTape(tape)
                root.aimedFilm = film
                root.aimedInfo = film >= 0 ? shop.film(film) : null
            }
        }
    }

    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: root.location = store.aisleAt(player.x, player.z)
    }

    // ---------------------------------------------------------------- scene
    // Two layers with the same camera. Underneath: the city, always drawn as
    // ASCII. On top: the shop itself, drawn normally, with a transparent
    // background; the city's buildings are in it too, but invisible, so they
    // still hide the shop where they stand in front of it.
    component PlayerCamera: PerspectiveCamera {
        position: Qt.vector3d(player.x, root.eye + (player.moving ? Math.sin(player.bob) * 2.2 : 0), player.z)
        eulerRotation: Qt.vector3d(player.pitch, player.yaw, 0)
        fieldOfView: 66
        clipNear: 5
        clipFar: 20000
    }

    // Everything 3D (street, shop, rain) goes through one post-process: glow
    // on the bright parts and a film-like colour grade. Off on Low.
    Item {
        id: world
        anchors.fill: parent
        visible: !ApplicationWindow.window || !ApplicationWindow.window.closing
        layer.enabled: root.quality >= 1
        layer.effect: PostFx { bloomStrength: root.quality >= 2 ? 0.8 : 0.65 }

    View3D {
        id: cityView
        anchors.fill: parent
        explicitTextureWidth: root.texW(cityView)
        explicitTextureHeight: root.texH(cityView)
        camera: cityCamera

        environment: SceneEnvironment {
            backgroundMode: SceneEnvironment.Color
            clearColor: "#04050b"
            antialiasingMode: SceneEnvironment.NoAA // the ASCII effect hides jaggies
            tonemapMode: SceneEnvironment.TonemapModeFilmic
            fog: Fog {
                enabled: true
                color: "#0a0d1c"
                depthEnabled: true
                depthNear: 1200
                depthFar: 7500
            }
            effects: devNoAscii ? [] : [asciiEffect]
        }

        Effect {
            id: asciiEffect
            property real strength: 1
            property real cellSize: Math.max(7, 11 * root.renderScale * Screen.devicePixelRatio) // same look at any render scale
            property real glyphCount: 10
            property TextureInput glyphs: TextureInput {
                texture: Texture {
                    minFilter: Texture.Linear
                    magFilter: Texture.Linear
                    sourceItem: Rectangle {
                        width: 10 * 24
                        height: 40
                        color: "black"
                        Row {
                            Repeater {
                                model: [" ", ".", ":", "-", "=", "+", "*", "#", "%", "@"]
                                Text {
                                    required property string modelData
                                    width: 24
                                    height: 40
                                    text: modelData
                                    color: "white"
                                    font.family: Theme.mono
                                    font.pixelSize: 30
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                }
            }
            passes: Pass {
                shaders: Shader {
                    stage: Shader.Fragment
                    shader: "ascii.frag"
                }
            }
        }

        PlayerCamera { id: cityCamera }

        DirectionalLight {
            eulerRotation: Qt.vector3d(-60, 30, 0)
            brightness: 0.45
            ambientColor: "#2a3046"
        }
        Store3DStreet { }
    }

    View3D {
        id: shopView
        anchors.fill: parent
        explicitTextureWidth: root.texW(shopView)
        explicitTextureHeight: root.texH(shopView)
        camera: shopCamera

        environment: SceneEnvironment {
            backgroundMode: SceneEnvironment.Transparent
            // Anti-aliasing and ambient occlusion are the costliest parts of a
            // frame on integrated GPUs: only on High.
            antialiasingMode: root.quality >= 2 ? SceneEnvironment.MSAA : SceneEnvironment.NoAA
            antialiasingQuality: SceneEnvironment.Medium
            tonemapMode: SceneEnvironment.TonemapModeFilmic
            aoStrength: root.quality >= 2 ? 30 : 0
            aoDistance: 40
            aoSoftness: 40
            // (No bloom: post effects break this layer's transparency.)
            lightmapper: Lightmapper {
                id: lightmapper
                bounces: 2
                samples: 32
                indirectLightFactor: 1.25
                // These exist from Qt 6.10 (where baking is supported).
                Component.onCompleted: if (baker.supported) {
                    lightmapper.source = baker.lightmapUrl
                    lightmapper.texelsPerUnit = 0.03
                    lightmapper.denoiseSigma = 8
                }
            }
        }

        PlayerCamera { id: shopCamera }

        Node {
        id: shopScene

        // ------------------------------------------------ lighting
        // Inside: even fluorescent light. A soft overhead light with a light
        // grey ambient does most of the work (and casts the shelf shadows);
        // point lights sit exactly at ceiling fittings for the falloff
        // between them. No coloured lights indoors.
        DirectionalLight {
            eulerRotation: Qt.vector3d(-90, 0, 0)
            brightness: 0.3
            color: "#f4f6ff"
            ambientColor: "#32353c"
            castsShadow: root.quality >= 1
            bakeMode: root.bake ? Light.BakeModeIndirect : Light.BakeModeDisabled
            shadowMapQuality: Light.ShadowMapQualityMedium
            shadowFactor: 30
            pcfFactor: 6
        }
        Repeater3D {
            model: 6
            PointLight {
                required property int index
                // snapped to the troffer grid in Store3DInterior (300 cm, from the back-left corner)
                readonly property real wx: -store.halfWidth + 150 + Math.round((store.halfWidth * (index % 2 === 0 ? 0.55 : 1.45) - 150) / 300) * 300
                readonly property real wz: store.backZ + 150 + Math.round(((store.frontZ - store.backZ) * (0.16 + Math.floor(index / 2) * 0.3) - 150) / 300) * 300
                position: Qt.vector3d(wx, 318, wz)
                color: "#eef2ff"
                brightness: 1.7
                constantFade: 1
                linearFade: 0
                quadraticFade: 0.35
                bakeMode: root.bake ? Light.BakeModeIndirect : Light.BakeModeDisabled
            }
        }

        // Outside: warm street lamps, placed exactly at the lamp heads of the
        // street (same spacing as Store3DStreet), and downlights in the
        // shop's canopy.
        Repeater3D {
            model: root.nearLamps
            PointLight {
                required property var modelData
                position: Qt.vector3d(modelData, 455, store.frontZ + 360)
                color: "#ffcf8f"
                brightness: 2.4
                constantFade: 1
                linearFade: 0
                quadraticFade: 0.6
            }
        }
        Repeater3D { // canopy downlights: bright pools on the wet pavement
            model: 4
            SpotLight {
                required property int index
                position: Qt.vector3d((index - 1.5) * (store.halfWidth * 0.55), 266, store.frontZ + 50)
                eulerRotation.x: -90
                color: "#fff3dc"
                brightness: 5
                coneAngle: 70
                innerConeAngle: 30
                quadraticFade: 1.1
            }
        }

        CoverAtlas {
            id: atlas
            films: shop.films
        }

        Clerk {
            position: store.clerk
            lookAt: Qt.vector3d(player.x, 0, player.z)
            talking: clerkDialog.visible
        }
        MembershipCard3D { position: root.cardPos; lit: root.aimCard }
        Store3DBackWall { }
        Store3DInterior {
            detail: root.quality >= 1
            lightPools: root.quality >= 1 ? 1 : 0
            radioStation: root.radioStation
            bake: root.bake
        }
        Store3DFacade { doorOpen: root.doorOpen }
        // Street shapes, invisible, so they hide the shop when they stand in
        // front of it. From inside nothing on the street can, so skip them.
        Store3DStreet { holdout: true; visible: root.outdoors > 0.01 }

        // Tapes: one instanced draw for every tape in the shop.
        TapeInstancing {
            id: tapeInstances
            layout: shop.store
            atlas: atlas
        }
        Model {
            source: "#Cube"
            instancing: tapeInstances
            materials: CustomMaterial {
                shadingMode: CustomMaterial.Shaded
                vertexShader: "tape.vert"
                fragmentShader: "tape.frag"
                property TextureInput atlas: TextureInput {
                    texture: Texture {
                        textureData: atlas
                        generateMipmaps: true
                        mipFilter: Texture.Linear
                    }
                }
            }
        }

        // Glow around the tape you're looking at (or the one the clerk found).
        Model {
            readonly property int tape: root.aimedTape >= 0 ? root.aimedTape : root.markedTape
            readonly property var info: tape >= 0 ? store.tapeInfo(tape) : null
            visible: info !== null
            source: "#Cube"
            position: info ? info.position : Qt.vector3d(0, 0, 0)
            eulerRotation: Qt.vector3d(info && info.lying ? -90 : -6, info ? info.yaw : 0, 0)
            scale: Qt.vector3d(0.165, 0.262, 0.062) // a little bigger than a tape (StoreLayout::Tape*)
            materials: PrincipledMaterial {
                baseColor: "#ffd21f"
                emissiveFactor: Qt.vector3d(0.9, 0.7, 0.1)
                opacity: 0.35
                alphaMode: PrincipledMaterial.Blend
                lighting: PrincipledMaterial.NoLighting
            }
        }
        } // shopScene

        // The wet pavement in front of the shop.
        Store3DForecourt {
            detail: root.quality >= 1
            beams: root.quality >= 1
            lamps: root.nearLamps
        }
    }



    // Rain gets its own layer on top, so drops falling in front of the shop
    // stay in front of it. The shop front is in it too, invisibly, so the
    // drops behind it stay hidden. Drops are little "|" characters to match
    // the ASCII city.
    View3D {
        id: rainView
        anchors.fill: parent
        explicitTextureWidth: root.texW(rainView)
        explicitTextureHeight: root.texH(rainView)
        camera: rainCamera
        environment: SceneEnvironment {
            backgroundMode: SceneEnvironment.Transparent
            antialiasingMode: root.quality >= 1 ? SceneEnvironment.MSAA : SceneEnvironment.NoAA
            antialiasingQuality: SceneEnvironment.Medium
        }
        PlayerCamera {
            id: rainCamera
            HeldDiary {
                id: heldDiary
                raise: root.diaryRaise
                pages: root.diaryPages
            }
            PointLight { // lights your hands and the umbrella from in front
                position: Qt.vector3d(0, 30, 20)
                brightness: 0.9
                color: "#fff1dc"
                quadraticFade: 2
            }
            // Opens when you step outside, folds away when you go in.
            Umbrella {
                id: umbrella
                property real target: root.outdoors > 0.5 ? 1 : 0
                open: target
                Behavior on open { NumberAnimation { duration: 650; easing.type: Easing.OutCubic } }
                visible: open > 0.02
                // Held up and slightly right; sways as you walk.
                position: Qt.vector3d(24, -64 + open * 58 + (player.moving ? Math.sin(player.bob) * 1.5 : 0), -22)
                eulerRotation: Qt.vector3d(-4 + (player.moving ? Math.cos(player.bob * 0.5) * 1.5 : 0),
                                           0, 5 + (player.moving ? Math.sin(player.bob * 0.5) * 2 : 0))
            }
        }
        // Light for the umbrella: dim sky from above, warm street lamps from below.
        DirectionalLight { eulerRotation: Qt.vector3d(-70, 20, 0); brightness: 0.35; ambientColor: "#2b2c36" }
        DirectionalLight { eulerRotation: Qt.vector3d(60, 160, 0); brightness: 0.55; color: "#ffcf9a" }
        Store3DFrontHoldout { }

        ParticleSystem3D {
            opacity: root.outdoors // the ASCII city already shows the rain through the windows
            SpriteParticle3D {
                id: drop
                maxAmount: 1600
                billboard: true
                blendMode: SpriteParticle3D.Screen
                color: "#9fc0ff"
                sprite: Texture {
                    sourceItem: Text {
                        width: 32
                        height: 64
                        text: "|"
                        color: "white"
                        font.family: Theme.mono
                        font.pixelSize: 44
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
            ParticleEmitter3D {
                particle: drop
                position: Qt.vector3d(player.x, 1300, store.frontZ + 1150)
                shape: ParticleShape3D {
                    type: ParticleShape3D.Cube
                    extents: Qt.vector3d(1700, 20, 1100)
                }
                particleScale: 4.5
                emitRate: root.quality === 0 ? 500 : 1400
                lifeSpan: 1000
                velocity: VectorDirection3D {
                    direction: Qt.vector3d(-60, -1450, 0)
                    directionVariation: Qt.vector3d(20, 150, 20)
                }
            }
        }
    }

    }

    // Opening: the 3D world fades in from night-black once it has had time
    // to set up, so the first frames (shaders compiling, the glow pass still
    // empty, covers loading) never flash on screen.
    Rectangle {
        anchors.fill: world
        color: "#04050b"
        opacity: 1 - root.wake
        visible: opacity > 0
    }

    // ---------------------------------------------------------------- input
    // Mouse look: while the mouse is captured, moving it turns your head. The
    // pointer is hidden and held in the middle of the window, so you can keep
    // turning. Hold Alt to get the pointer back for the buttons.
    // The street lamps nearest the shop (same spacing as Store3DStreet).
    readonly property var nearLamps: {
        const out = []
        const half = store.streetHalfWidth
        for (let x = -half + 450; x < half; x += 900)
            if (Math.abs(x) > 400 && Math.abs(x) < 1900) out.push(x)
        return out
    }

    // Remembered settings (the pause menu changes them).
    property bool muted: devMute || shop.pref("muted", false) === true || shop.pref("muted", false) === "true"
    property real volume: Number(shop.pref("volume", 1))
    property real sensitivity: Number(shop.pref("sensitivity", 0.14))
    // Graphics quality: 0 low, 1 medium (default), 2 high.
    property int quality: Number(shop.pref("quality", 1))
    onQualityChanged: shop.setPref("quality", quality)
    // The 3D is drawn at a fraction of the window's pixels and scaled up:
    // the single biggest saving on laptop GPUs. Menus and text stay sharp.
    readonly property real renderScale: [0.6, 0.8, 1.0][quality]
    function texW(item) { return renderScale < 1 ? Math.round(item.width * Screen.devicePixelRatio * renderScale) : 0 }
    function texH(item) { return renderScale < 1 ? Math.round(item.height * Screen.devicePixelRatio * renderScale) : 0 }
    onMutedChanged: if (!devMute) shop.setPref("muted", muted)
    onVolumeChanged: shop.setPref("volume", volume)
    onSensitivityChanged: shop.setPref("sensitivity", sensitivity)
    property bool captured: false
    onCapturedChanged: if (pointer.debug) console.info("look: captured", captured, "uiOpen", uiOpen, "reading", reading)

    function capture() {
        if (uiOpen || reading)
            return
        captured = true
        keys.forceActiveFocus()
        look.recenter()
    }
    function release() {
        captured = false
    }

    Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state !== Qt.ApplicationActive)
                root.release()
        }
    }

    // Mouse look comes from real mouse motion only (see PointerHelper);
    // this area just handles clicks, the cursor and the Wayland edge-turn.
    Binding { target: pointer; property: "active"; value: root.captured }
    Connections {
        target: pointer
        function onMoved(dx, dy) {
            if (pointer.debug)
                console.info("look: moved", dx, dy, "uiOpen", root.uiOpen, "travel", travel.running,
                             "captured", root.captured, "yaw", player.yaw.toFixed(1))
            if (root.uiOpen || travel.running)
                return
            player.yaw -= dx * root.sensitivity
            player.pitch = Math.max(-80, Math.min(80, player.pitch - dy * root.sensitivity))
        }
    }

    MouseArea {
        id: look
        anchors.fill: parent
        hoverEnabled: true
        property real lastX: width / 2
        cursorShape: root.reading ? Qt.ArrowCursor
                     : root.captured && pointer.canWarp ? Qt.BlankCursor : Qt.CrossCursor
        function recenter() { pointer.recenter() }
        Component.onCompleted: pointer.attach(look)
        onPositionChanged: mouse => {
            lastX = mouse.x // for edge-turning on native Wayland
            if (root.reading) {
                const p = root.diaryPoint(mouse.x, mouse.y)
                if (p) root.diaryPages.hoverAt(p.x, p.y)
                else root.diaryPages.hovered = -1
            }
        }
        onWheel: wheel => {
            if (root.reading)
                root.diaryPages.scrollBy(wheel.angleDelta.y > 0 ? -1 : 1)
        }
        onClicked: mouse => {
            if (root.reading) {
                keys.forceActiveFocus()
                const p = root.diaryPoint(mouse.x, mouse.y)
                if (!p) { // clicked outside the book: put it away
                    root.closeDiary()
                    return
                }
                const film = root.diaryPages.clickAt(p.x, p.y)
                if (film >= 0) {
                    root.closeDiary()
                    vhsCase.show(film)
                }
                return
            }
            root.captured ? root.pickUp() : root.capture()
        }
    }

    Item {
        id: keys
        focus: true
        Component.onCompleted: forceActiveFocus()

        function set(key, down) {
            switch (key) {
            case Qt.Key_W: case Qt.Key_Up: player.forward = down; return true
            case Qt.Key_S: case Qt.Key_Down: player.back = down; return true
            case Qt.Key_A: player.left = down; return true
            case Qt.Key_D: player.right = down; return true
            case Qt.Key_Left: case Qt.Key_Q: player.turnLeft = down; return true
            case Qt.Key_Right: player.turnRight = down; return true
            case Qt.Key_Shift: player.run = down; return true
            }
            return false
        }
        Keys.onPressed: event => {
            if (pointer.debug && !event.isAutoRepeat)
                console.info("key: press", event.key, "captured", root.captured)
            // An open panel gets the keys first: its own key (or Esc) closes
            // it, and nothing else opens on top of it.
            if (root.handlePanelKey(event.key)) {
                event.accepted = true
                return
            }
            if (root.reading) { // the diary in your hands
                const k = event.key
                if (k === Qt.Key_J || k === Qt.Key_Escape || k === Qt.Key_Tab) root.closeDiary()
                else if (k === Qt.Key_Left || k === Qt.Key_A) root.diaryPages.stepMonth(-1)
                else if (k === Qt.Key_Right || k === Qt.Key_D) root.diaryPages.stepMonth(1)
                else if (k === Qt.Key_Up || k === Qt.Key_W) root.diaryPages.moveSelection(-1)
                else if (k === Qt.Key_Down || k === Qt.Key_S) root.diaryPages.moveSelection(1)
                else if (k === Qt.Key_PageUp || k === Qt.Key_Q) root.diaryPages.stepYear(-1)
                else if (k === Qt.Key_PageDown) root.diaryPages.stepYear(1)
                else if (k === Qt.Key_E || k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
                    const e = root.diaryPages.selectedEntry
                    if (e) {
                        root.closeDiary()
                        vhsCase.show(e.index)
                    }
                } else if (k === Qt.Key_Alt) root.release()
                event.accepted = true
                return
            }
            if (event.isAutoRepeat) { event.accepted = true; return }
            if (event.key === Qt.Key_J || event.key === Qt.Key_Tab) { root.openDiary(); event.accepted = true; return }
            if (set(event.key, true)) { event.accepted = true; return }
            if (event.key === Qt.Key_E || event.key === Qt.Key_Space || event.key === Qt.Key_Return) {
                root.pickUp(); event.accepted = true
            } else if (event.key === Qt.Key_Alt) {
                root.release(); event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
                pauseMenu.open(); event.accepted = true
            } else if (event.key === Qt.Key_M) {
                storeMap.open(); event.accepted = true
            } else if (event.key === Qt.Key_C) {
                memberCard.open(); event.accepted = true
            } else if (event.key === Qt.Key_F) {
                clerkDialog.open(); event.accepted = true // "excuse me!"
            }
        }
        Keys.onReleased: event => {
            if (event.isAutoRepeat)
                return
            if (set(event.key, false)) {
                event.accepted = true
            } else if (event.key === Qt.Key_Alt) {
                root.capture() // let go of Alt: back to looking around
                event.accepted = true
            }
        }
    }

    // Stop walking when focus moves to a popup or the search box.
    onUiOpenChanged: {
        if (uiOpen) {
            player.forward = player.back = player.left = player.right = false
            player.turnLeft = player.turnRight = player.run = false
            release()
        } else {
            capture() // back to looking around after a popup closes
        }
    }

    // ---------------------------------------------------------------- HUD
    // Crosshair.
    Rectangle {
        anchors.centerIn: parent
        width: root.aimedFilm >= 0 ? 18 : 6
        height: width
        radius: width / 2
        color: root.aimedFilm >= 0 ? "transparent" : "#ccffffff"
        border.color: root.aimedFilm >= 0 ? Theme.yellow : "#80000000"
        border.width: 2
        Behavior on width { NumberAnimation { duration: 90 } }
    }

    // Shown while the mouse is free.
    Rectangle {
        visible: !root.captured && !root.uiOpen && !root.reading
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -70
        width: freeText.implicitWidth + 36
        height: 44
        radius: 22
        color: "#d8081030"
        border.color: Theme.cyan
        border.width: 2
        Text {
            id: freeText
            anchors.centerIn: parent
            text: "Click (or let go of Alt) to look around"
            color: Theme.cyan
            font.pixelSize: 15
            font.weight: Font.Bold
        }
    }

    // Looking at the radio.
    Rectangle {
        visible: root.aimRadio
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60
        width: radioText.implicitWidth + 48
        height: 74
        radius: 10
        color: "#d8081030"
        border.color: "#ffb347"
        border.width: 2
        Column {
            id: radioText
            anchors.centerIn: parent
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "RADIO · " + root.stations[root.radioStation]
                color: Theme.text
                font.pixelSize: 20
                font.weight: Font.Bold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "click or E to " + (root.radioStation === root.stations.length - 1 ? "switch it off" : "change station")
                color: Theme.dim
                font.pixelSize: 13
            }
        }
    }

    // Looking at your membership card.
    Rectangle {
        visible: root.aimCard
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60
        width: cardText.implicitWidth + 48
        height: 74
        radius: 10
        color: "#d8081030"
        border.color: Theme.yellow
        border.width: 2
        Column {
            id: cardText
            anchors.centerIn: parent
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "YOUR MEMBERSHIP CARD"
                color: Theme.text
                font.pixelSize: 20
                font.weight: Font.Bold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "click or E to look at it  ·  C from anywhere"
                color: Theme.dim
                font.pixelSize: 13
            }
        }
    }

    // Looking at the clerk.
    Rectangle {
        visible: root.aimClerk
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60
        width: clerkText.implicitWidth + 48
        height: 74
        radius: 10
        color: "#d8081030"
        border.color: Theme.yellow
        border.width: 2
        Column {
            id: clerkText
            anchors.centerIn: parent
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "DALE · store clerk"
                color: Theme.text
                font.pixelSize: 20
                font.weight: Font.Bold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "click or E to ask for a film"
                color: Theme.dim
                font.pixelSize: 13
            }
        }
    }
    // What you're looking at.
    Rectangle {
        visible: root.aimedInfo !== null && !root.reading
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60
        width: Math.min(560, aimText.implicitWidth + 48)
        height: 74
        radius: 10
        color: "#d8081030"
        border.color: Theme.yellow
        border.width: 2
        Column {
            id: aimText
            anchors.centerIn: parent
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, 512)
                elide: Text.ElideRight
                text: root.aimedInfo ? root.aimedInfo.name : ""
                color: Theme.text
                font.pixelSize: 20
                font.weight: Font.Bold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: !root.aimedInfo ? "" :
                      [root.aimedInfo.year > 0 ? root.aimedInfo.year : "",
                       root.aimedInfo.isTv ? "TV series" : "",
                       Theme.stars(root.aimedInfo.rating),
                       root.aimedInfo.liked ? "♥" : "",
                       "click or E to pick up"].filter(s => s !== "").join("   ·   ")
                color: Theme.dim
                font.pixelSize: 13
            }
        }
    }

    // Where you are.
    Rectangle {
        anchors { left: parent.left; top: parent.top; margins: 18 }
        visible: root.location !== ""
        width: locText.implicitWidth + 28
        height: 38
        radius: 19
        color: "#b0081030"
        Text {
            id: locText
            anchors.centerIn: parent
            text: root.location
            color: Theme.yellow
            font.pixelSize: 15
            font.weight: Font.Black
            font.letterSpacing: 1
        }
    }

    // Controls hint, fades after a while.
    Text {
        id: hint
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 22 }
        text: "WASD walk  ·  mouse look  ·  click a tape  ·  J diary  ·  M map  ·  C card  ·  ask Dale for a film  ·  Alt pointer  ·  Esc menu"
        color: "white"
        style: Text.Outline
        styleColor: "#000000"
        font.pixelSize: 14
        opacity: 1
        SequentialAnimation on opacity {
            PauseAnimation { duration: 9000 }
            NumberAnimation { to: 0; duration: 1500 }
        }
    }

    // Status (stocking / covers).
    Text {
        anchors { right: parent.right; top: parent.top; margins: 22 }
        color: shop.tmdbError !== "" ? Theme.red : Theme.dim
        style: Text.Outline
        styleColor: "#000000"
        font.pixelSize: 13
        text: baker.baking ? "Baking lighting… " + Math.round(baker.progress * 100) + "%  " + baker.status
              : shop.stocking ? "Stocking shelves… " + shop.stockDone + " / " + shop.stockTotal
              : shop.tmdbError !== "" ? shop.tmdbError
              : atlas.loading > 0 ? "Unpacking covers… " + atlas.loading
              : shop.tmdbKey === "" ? "No cover art yet: add a TMDB key on your card" : ""
    }

    // Returns true if the key was used by an open panel.
    function handlePanelKey(k) {
        const esc = k === Qt.Key_Escape
        if (pauseMenu.visible) {
            if (esc) pauseMenu.back()
            return true
        }
        if (storeMap.visible) {
            if (esc || k === Qt.Key_M) storeMap.close()
            return true
        }
        if (memberCard.visible) {
            if (esc || k === Qt.Key_C) memberCard.close()
            return true
        }
        if (vhsCase.visible) {
            if (esc) vhsCase.close()
            return true
        }
        if (clerkDialog.visible) {
            if (esc) clerkDialog.close()
            return true
        }
        return false
    }

    function goToFilm(index) {
        keys.forceActiveFocus()
        travelTo(store.viewFilm(index))
    }

    VhsCase {
        id: vhsCase
        onClosed: keys.forceActiveFocus()
        onLocate: index => root.travelTo(store.viewFilm(index))
    }
    ClerkDialog {
        id: clerkDialog
        onGoToFilm: i => root.goToFilm(i)
        onShowFilm: i => vhsCase.show(i)
        onClosed: keys.forceActiveFocus()
    }
    PauseMenu {
        id: pauseMenu
        game: root
        onOpenMap: storeMap.open()
        onOpenCard: memberCard.open()
        onGoOutside: root.travelTo({x: store.entrance.x, z: store.entrance.z, yaw: 0, pitch: -2})
        onBakeRequested: root.bakeLighting()
        onClosed: keys.forceActiveFocus()
    }
    MemberCard {
        id: memberCard
        onClosed: keys.forceActiveFocus()
    }
    StoreMap {
        id: storeMap
        playerX: player.x
        playerZ: player.z
        playerYaw: player.yaw
        onCategoryPicked: i => root.travelTo(store.viewCategory(i))
        onClosed: keys.forceActiveFocus()
    }
}
