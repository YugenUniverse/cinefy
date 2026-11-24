import QtQuick
import QtQuick3D

// The shop front seen from the street, drawn clear (not ASCII): a backlit
// arrow sign on the roof, a blue canopy band with a backlit "new releases"
// banner and downlights, automatic sliding doors, a return box on the
// pavement, and posters taped inside the windows.
Node {
    id: facade
    readonly property var store: shop.store
    readonly property real front: store.frontZ
    property real doorOpen: 0 // 0 closed .. 1 open, set by Store3D
    property real shutter: 0  // 1 down (shop shut) .. 0 rolled up, set by Store3D

    component Metal: Model {
        property color tint: "#a8adb4"
        source: "#Cube"
        materials: PrincipledMaterial { baseColor: tint; metalness: 0.75; roughness: 0.35 }
    }

    // ------------------------------------------------------------ roof edge, drainpipes
    Metal { // coping along the top of the shop front
        position: Qt.vector3d(0, 464, facade.front + 4)
        scale: Qt.vector3d(store.halfWidth * 2 / 100 + 0.2, 0.08, 0.3)
        tint: "#8b9097"
    }
    Repeater3D {
        model: 2
        Model {
            required property int index
            source: "#Cylinder"
            position: Qt.vector3d((index === 0 ? -1 : 1) * (store.halfWidth - 14), 232, facade.front + 14)
            scale: Qt.vector3d(0.07, 4.64, 0.07)
            materials: PrincipledMaterial { baseColor: "#5f646b"; metalness: 0.6; roughness: 0.5 }
        }
    }

    // ------------------------------------------------------------ the big sign
    // A backlit arrow-shaped sign standing on the roof.
    Texture {
        id: signArt
        sourceItem: Canvas {
            width: 1024
            height: 240
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                function arrow(inset) {
                    ctx.beginPath()
                    ctx.moveTo(20 + inset, 20 + inset)
                    ctx.lineTo(860 - inset * 0.6, 20 + inset)
                    ctx.lineTo(1004 - inset * 1.6, 120)
                    ctx.lineTo(860 - inset * 0.6, 220 - inset)
                    ctx.lineTo(20 + inset, 220 - inset)
                    ctx.closePath()
                }
                ctx.fillStyle = "#ffd21f"; arrow(0); ctx.fill()        // yellow rim
                ctx.fillStyle = "#1f5ce0"; arrow(12); ctx.fill()       // blue face
                ctx.fillStyle = "#ffd21f"
                ctx.font = "900 104px sans-serif"
                ctx.textBaseline = "middle"
                ctx.textAlign = "center"
                ctx.fillText("CINEFY VIDEO", 450, 124)
            }
        }
    }
    Model {
        source: "#Rectangle"
        position: Qt.vector3d(-40, 520, facade.front + 30)
        scale: Qt.vector3d(5.4, 1.27, 1)
        castsShadows: false
        materials: PrincipledMaterial {
            baseColorMap: signArt
            emissiveMap: signArt
            emissiveFactor: Qt.vector3d(0.9, 0.9, 0.9) // lit from inside
            alphaMode: PrincipledMaterial.Blend
            cullMode: Material.NoCulling
        }
    }
    Repeater3D { // the posts it stands on
        model: 2
        Metal {
            required property int index
            tint: "#3a3d45"
            position: Qt.vector3d(-240 + index * 380, 472, facade.front + 26)
            scale: Qt.vector3d(0.06, 0.4, 0.06)
        }
    }

    // ------------------------------------------------------------ canopy band
    // Deep blue band across the front with a backlit banner, a glowing yellow
    // stripe underneath and downlights in its underside.
    readonly property real bandW: store.halfWidth * 2 + 40
    Model {
        source: "#Cube"
        position: Qt.vector3d(0, 332, facade.front + 45)
        scale: Qt.vector3d(facade.bandW / 100, 1.24, 0.9)
        materials: PrincipledMaterial {
            baseColor: "#1a4fc4"
            emissiveFactor: Qt.vector3d(0.03, 0.08, 0.28) // edge-lit
            roughness: 0.45
        }
    }
    Model { // glowing yellow stripe
        source: "#Cube"
        position: Qt.vector3d(0, 274, facade.front + 90.5)
        scale: Qt.vector3d(facade.bandW / 100, 0.05, 0.02)
        materials: PrincipledMaterial {
            baseColor: "#ffd21f"
            emissiveFactor: Qt.vector3d(1.0, 0.82, 0.12)
            lighting: PrincipledMaterial.NoLighting
        }
    }
    Texture {
        id: bannerArt
        sourceItem: Canvas {
            width: 1400
            height: 200
            onPaint: {
                const ctx = getContext("2d")
                ctx.fillStyle = "#f4f6fb"
                ctx.fillRect(0, 0, width, height)
                ctx.strokeStyle = "#c9d2e6"
                ctx.lineWidth = 6
                ctx.strokeRect(3, 3, width - 6, height - 6)
                ctx.fillStyle = "#1f3f99"
                ctx.font = "italic 900 118px sans-serif"
                ctx.textBaseline = "middle"
                ctx.fillText("NEW RELEASES", 60, 104)
                // red starburst
                const cx = 1210, cy = 100, spikes = 18
                ctx.beginPath()
                for (let i = 0; i < spikes * 2; ++i) {
                    const r = i % 2 === 0 ? 92 : 74
                    const a = Math.PI * i / spikes - Math.PI / 2
                    ctx.lineTo(cx + r * Math.cos(a), cy + r * Math.sin(a))
                }
                ctx.closePath()
                ctx.fillStyle = "#d6231f"
                ctx.fill()
                ctx.fillStyle = "#ffe14a"
                ctx.font = "900 32px sans-serif"
                ctx.textAlign = "center"
                ctx.fillText("EVERY", cx, cy - 20)
                ctx.fillText("TUESDAY", cx, cy + 24)
            }
        }
    }
    Model { // the banner, backlit
        source: "#Rectangle"
        position: Qt.vector3d(0, 336, facade.front + 90.6)
        scale: Qt.vector3d(Math.min(7.6, facade.bandW / 100 * 0.62), Math.min(7.6, facade.bandW / 100 * 0.62) / 7, 1)
        castsShadows: false
        materials: PrincipledMaterial {
            baseColorMap: bannerArt
            emissiveMap: bannerArt
            emissiveFactor: Qt.vector3d(0.55, 0.55, 0.55)
        }
    }
    Repeater3D { // downlights in the canopy's underside
        model: Math.floor(facade.bandW / 240)
        Model {
            required property int index
            source: "#Cylinder"
            position: Qt.vector3d(-facade.bandW / 2 + 120 + index * 240, 269.5, facade.front + 45)
            scale: Qt.vector3d(0.14, 0.01, 0.14)
            castsShadows: false
            materials: PrincipledMaterial {
                baseColor: "#fff6e0"
                emissiveFactor: Qt.vector3d(1, 0.95, 0.85)
                lighting: PrincipledMaterial.NoLighting
            }
        }
    }

    // ------------------------------------------------------------ return box
    Node {
        position: store.dropBox
        eulerRotation.y: -8
        Model { // body
            source: "#Cube"
            y: 58
            scale: Qt.vector3d(0.6, 1.0, 0.5)
            materials: PrincipledMaterial { baseColor: "#1a4fc4"; roughness: 0.35; metalness: 0.2 }
        }
        Model { // rounded top
            source: "#Cylinder"
            position: Qt.vector3d(0, 108, 0)
            eulerRotation.z: 90
            scale: Qt.vector3d(0.5, 0.6, 0.5)
            materials: PrincipledMaterial { baseColor: "#1a4fc4"; roughness: 0.35; metalness: 0.2 }
        }
        Model { // the flap
            source: "#Cube"
            position: Qt.vector3d(0, 92, 25.5)
            scale: Qt.vector3d(0.42, 0.1, 0.01)
            materials: PrincipledMaterial { baseColor: "#0c1c4a"; roughness: 0.3 }
        }
        Node {
            position: Qt.vector3d(-26, 74, 25.6)
            scale: Qt.vector3d(0.1, 0.1, 0.1)
            Rectangle {
                width: 520
                height: 230
                color: "transparent"
                Column {
                    anchors.centerIn: parent
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "CINEFY"
                        color: "#ffd21f"
                        font.weight: Font.Black
                        font.pixelSize: 80
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "MOVIE RETURNS"
                        color: "white"
                        font.weight: Font.Black
                        font.pixelSize: 52
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ door
    Repeater3D { // aluminium frame around the doorway
        model: 3
        Metal {
            required property int index
            position: index < 2 ? Qt.vector3d((index === 0 ? -1 : 1) * (store.doorHalfWidth + 2), 120, facade.front)
                                : Qt.vector3d(0, 241, facade.front)
            scale: index < 2 ? Qt.vector3d(0.06, 2.4, 0.18) : Qt.vector3d(store.doorHalfWidth * 2 / 100 + 0.1, 0.06, 0.18)
        }
    }
    // Two automatic glass doors that slide apart as you come near.
    Repeater3D {
        model: 2
        Node {
            id: leaf
            required property int index
            readonly property int s: index === 0 ? -1 : 1
            readonly property real half: store.doorHalfWidth / 2
            position: Qt.vector3d(s * (half + facade.doorOpen * (store.doorHalfWidth - 8)), 0, facade.front + (index === 0 ? -2 : 2))
            Repeater3D { // frame of the leaf
                model: 4
                Metal {
                    required property int index
                    position: index < 2 ? Qt.vector3d((index === 0 ? -1 : 1) * (leaf.half - 2), 118, 0)
                                        : Qt.vector3d(0, index === 2 ? 3 : 234, 0)
                    scale: index < 2 ? Qt.vector3d(0.04, 2.34, 0.05) : Qt.vector3d(leaf.half * 2 / 100, index === 2 ? 0.06 : 0.04, 0.05)
                }
            }
            Model { // glass
                source: "#Rectangle"
                y: 118
                scale: Qt.vector3d((leaf.half * 2 - 6) / 100, 2.3, 1)
                materials: PrincipledMaterial {
                    baseColor: "#a9c7d6"
                    opacity: 0.16
                    alphaMode: PrincipledMaterial.Blend
                    roughness: 0.04
                    cullMode: Material.NoCulling
                }
            }
            Node { // sticker band on the glass
                position: Qt.vector3d(-leaf.half + 6, 128, 0.6)
                scale: Qt.vector3d(0.1, 0.1, 0.1)
                Rectangle {
                    width: (leaf.half * 2 - 12) * 10
                    height: 70
                    color: "#d0ffd21f"
                    Text {
                        anchors.centerIn: parent
                        text: leaf.index === 0 ? "OPEN 10AM – MIDNIGHT" : "AUTOMATIC DOOR"
                        color: "#1b1b1b"
                        font.weight: Font.Black
                        font.pixelSize: 40
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ window posters
    // Taped to the inside of the glass, slightly crooked; the tape shows.
    Repeater3D {
        model: Math.min(store.windowPosters.length, shop.windowPosters.length)
        Node {
            id: poster
            required property int index
            readonly property var spot: store.windowPosters[index]
            position: Qt.vector3d(spot.x, spot.y, facade.front - 1.5)
            eulerRotation.z: spot.tilt
            Model {
                source: "#Rectangle"
                scale: Qt.vector3d(poster.spot.w / 100, poster.spot.h / 100, 1)
                materials: PrincipledMaterial {
                    roughness: 0.6
                    baseColorMap: Texture {
                        sourceItem: Image {
                            width: 185
                            height: 278
                            source: shop.windowPosters[poster.index] || ""
                            sourceSize.width: 185
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                }
            }
            Model { // blank back, seen from inside
                source: "#Rectangle"
                z: -0.2
                eulerRotation.y: 180
                scale: Qt.vector3d(poster.spot.w / 100, poster.spot.h / 100, 1)
                materials: PrincipledMaterial { baseColor: "#e6e0d1"; roughness: 0.9 }
            }
            Repeater3D { // strips of tape over the corners
                model: poster.index % 3 === 0 ? 4 : 2
                Model {
                    required property int index
                    readonly property int cx: index % 2 === 0 ? -1 : 1
                    readonly property int cy: index < 2 ? 1 : -1
                    source: "#Rectangle"
                    position: Qt.vector3d(cx * poster.spot.w / 2, cy * poster.spot.h / 2, 0.3)
                    eulerRotation.z: cx * cy * -38
                    scale: Qt.vector3d(0.13, 0.04, 1)
                    materials: PrincipledMaterial {
                        baseColor: "#f1e4b8"
                        opacity: 0.75
                        alphaMode: PrincipledMaterial.Blend
                        roughness: 0.3
                        cullMode: Material.NoCulling
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ security shutters
    // Roller shutters over the door and both windows while the shop is shut.
    // They roll up into a box under the canopy; a note is taped on the door.
    component SlatArt: Canvas { // one ribbed galvanised slat; repeated up the shutter
        width: 256
        height: 32
        onPaint: {
            const ctx = getContext("2d")
            const g = ctx.createLinearGradient(0, 0, 0, height)
            g.addColorStop(0.0, "#5d636b")
            g.addColorStop(0.18, "#b9bfc6")
            g.addColorStop(0.5, "#8d939b")
            g.addColorStop(0.82, "#6b7179")
            g.addColorStop(1.0, "#3e434a")
            ctx.fillStyle = g
            ctx.fillRect(0, 0, width, height)
            let seed = 7
            const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647
            for (let i = 0; i < 260; ++i) { // grime and scuffs
                ctx.fillStyle = rnd() < 0.5 ? "rgba(30,32,36,0.18)" : "rgba(220,225,230,0.12)"
                ctx.fillRect(rnd() * width, rnd() * height, 1 + rnd() * 6, 1)
            }
        }
    }
    readonly property real openingTop: 240 // underside of the header over door and windows
    component Shutter: Node {
        id: sh
        property real x0
        property real x1
        property real bottom: 0 // sill height when shut
        readonly property real fullH: facade.openingTop - bottom
        readonly property real h: Math.max(0, fullH * facade.shutter)
        readonly property real w: x1 - x0
        visible: facade.shutter > 0.001
        Model { // the curtain of slats
            visible: sh.h > 0.5
            source: "#Rectangle"
            position: Qt.vector3d((sh.x0 + sh.x1) / 2, facade.openingTop - sh.h / 2, facade.front + 11)
            scale: Qt.vector3d(sh.w / 100, sh.h / 100, 1)
            castsShadows: false
            materials: PrincipledMaterial {
                baseColorMap: Texture {
                    sourceItem: SlatArt {}
                    tilingModeHorizontal: Texture.Repeat
                    tilingModeVertical: Texture.Repeat
                    scaleU: sh.w / 240
                    scaleV: sh.h / 7.5 // a slat every 7.5 cm
                }
                metalness: 0.55
                roughness: 0.5
                cullMode: Material.NoCulling
            }
        }
        Model { // bottom rail
            source: "#Cube"
            position: Qt.vector3d((sh.x0 + sh.x1) / 2, facade.openingTop - sh.h + 2, facade.front + 12)
            scale: Qt.vector3d(sh.w / 100, 0.05, 0.05)
            castsShadows: false
            materials: PrincipledMaterial { baseColor: "#3c4047"; metalness: 0.7; roughness: 0.4 }
        }
        Repeater3D { // guide rails either side
            model: 2
            Model {
                required property int index
                source: "#Cube"
                position: Qt.vector3d(index === 0 ? sh.x0 - 2 : sh.x1 + 2, (sh.bottom + facade.openingTop) / 2, facade.front + 11)
                scale: Qt.vector3d(0.05, sh.fullH / 100, 0.07)
                castsShadows: false
                materials: PrincipledMaterial { baseColor: "#4a4f57"; metalness: 0.7; roughness: 0.45 }
            }
        }
        Model { // the box it rolls up into
            source: "#Cube"
            position: Qt.vector3d((sh.x0 + sh.x1) / 2, facade.openingTop + 9, facade.front + 14)
            scale: Qt.vector3d((sh.w + 10) / 100, 0.2, 0.2)
            castsShadows: false
            materials: PrincipledMaterial { baseColor: "#50565e"; metalness: 0.6; roughness: 0.5 }
        }
    }
    readonly property real winInner: store.doorHalfWidth + 30
    readonly property real winOuter: store.halfWidth - 30
    Shutter { x0: -store.doorHalfWidth - 6; x1: store.doorHalfWidth + 6 }
    Shutter { x0: -facade.winOuter; x1: -facade.winInner; bottom: 70 }
    Shutter { x0: facade.winInner; x1: facade.winOuter; bottom: 70 }

    // A note taped to the door shutter, with how far the stocking has got.
    Node {
        // It rides up on the shutter and goes into the box with it.
        readonly property real lift: facade.openingTop * (1 - facade.shutter)
        visible: facade.shutter > 0 && lift + 132 + 39 < facade.openingTop
        position: Qt.vector3d(4, lift + 132, facade.front + 11.6)
        eulerRotation.z: -2.5
        Model {
            source: "#Rectangle"
            scale: Qt.vector3d(0.6, 0.78, 1)
            castsShadows: false
            materials: PrincipledMaterial {
                roughness: 0.85
                baseColorMap: Texture {
                    sourceItem: Rectangle {
                        width: 600
                        height: 780
                        color: "#f4f1e8"
                        Column {
                            anchors.fill: parent
                            anchors.margins: 36
                            spacing: 20
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                text: "SORRY,\nWE'RE STOCKING\nTHE SHELVES"
                                color: "#c4231d"
                                font.family: Theme.display
                                font.weight: Font.Black
                                font.pixelSize: 68
                                lineHeight: 0.9
                            }
                            Rectangle { width: parent.width; height: 8; color: "#1d2a6b" }
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: shop.stockTotal > 0 ? shop.stockDone + " of " + shop.stockTotal + " tapes"
                                                          : "putting the covers on…"
                                color: "#1d2a6b"
                                font.weight: Font.Black
                                font.pixelSize: 60
                            }
                            Rectangle { // progress, drawn like a marker-pen bar
                                width: parent.width
                                height: 60
                                color: "transparent"
                                border.color: "#1d2a6b"
                                border.width: 8
                                Rectangle {
                                    x: 12; y: 12
                                    height: parent.height - 24
                                    width: (parent.width - 24) * (shop.stockTotal > 0 ? shop.stockDone / shop.stockTotal : 1)
                                    color: "#1f5ce0"
                                }
                            }
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                text: "Opening in a minute!\n— the staff"
                                color: "#1d2a6b"
                                font.italic: true
                                font.weight: Font.Bold
                                font.pixelSize: 52
                            }
                        }
                    }
                }
            }
        }
        Repeater3D { // tape on the corners
            model: 2
            Model {
                required property int index
                source: "#Rectangle"
                position: Qt.vector3d((index === 0 ? -1 : 1) * 30, 39, 0.3)
                eulerRotation.z: index === 0 ? 35 : -35
                scale: Qt.vector3d(0.14, 0.04, 1)
                castsShadows: false
                materials: PrincipledMaterial { baseColor: "#f1e4b8"; opacity: 0.8; alphaMode: PrincipledMaterial.Blend; roughness: 0.3 }
            }
        }
    }

    // ------------------------------------------------------------ OPEN neon
    Node {
        id: openSign
        property real lit: 1
        position: Qt.vector3d(store.doorHalfWidth + 45, 215, facade.front - 6)
        scale: Qt.vector3d(0.25, 0.25, 0.25)
        // Switched on once the shutter is up: a couple of stutters, then on.
        property real power: facade.shutter > 0 ? 0 : 1
        Behavior on power {
            SequentialAnimation {
                PauseAnimation { duration: 300 }
                NumberAnimation { to: 0.8; duration: 40 }
                NumberAnimation { to: 0; duration: 120 }
                NumberAnimation { to: 1; duration: 50 }
                NumberAnimation { to: 0.15; duration: 90 }
                NumberAnimation { to: 1; duration: 60 }
            }
        }
        Text {
            readonly property real lit: openSign.lit * openSign.power
            text: "OPEN"
            color: Qt.rgba(1, 0.17, 0.84, 0.25 + 0.75 * lit)
            style: Text.Outline
            styleColor: Qt.rgba(1, 0.82, 0.96, lit)
            font.family: Theme.display
            font.weight: Font.Black
            font.pixelSize: 110
        }
        // Old neon: mostly steady, now and then it stutters.
        SequentialAnimation on lit {
            loops: Animation.Infinite
            PauseAnimation { duration: 5200 }
            NumberAnimation { to: 0.1; duration: 40 }
            NumberAnimation { to: 1; duration: 70 }
            NumberAnimation { to: 0.2; duration: 50 }
            NumberAnimation { to: 1; duration: 60 }
            PauseAnimation { duration: 2900 }
            NumberAnimation { to: 0.05; duration: 30 }
            PauseAnimation { duration: 260 }
            NumberAnimation { to: 1; duration: 90 }
        }
    }
}
