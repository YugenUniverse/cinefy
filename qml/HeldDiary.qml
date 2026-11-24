import QtQuick
import QtQuick3D

// The rental ledger held open in both hands, close to your face. Thumbs rest
// on the pages, fingers curl round behind the cover. `raise` goes
// 0 (down, out of view) → 1 (up, reading). `pageModel` is pickable, so the
// mouse can be mapped onto the pages.
Node {
    id: held
    property real raise: 0
    property Item pages // a DiaryPages item, drawn onto the paper
    readonly property alias pageModel: paper

    readonly property real bookW: 52
    readonly property real bookH: 32.5

    visible: raise > 0.01
    position: Qt.vector3d(0, -5 - (1 - raise) * 40, -39)
    eulerRotation: Qt.vector3d(-6 - (1 - raise) * 35, 0, 0)

    // ------------------------------------------------ the book
    Model { // binder cover, a little bigger than the pages
        source: "#Cube"
        z: -0.9
        scale: Qt.vector3d((held.bookW + 2.4) / 100, (held.bookH + 2.4) / 100, 0.016)
        materials: PrincipledMaterial { baseColor: "#1d2f6e"; roughness: 0.55 }
    }
    Model {
        id: paper
        source: "#Rectangle"
        pickable: true
        scale: Qt.vector3d(held.bookW / 100, held.bookH / 100, 1)
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColorMap: Texture {
                sourceItem: held.pages
                generateMipmaps: true
                mipFilter: Texture.Linear
            }
        }
    }

    // ------------------------------------------------ hands
    PrincipledMaterial {
        id: skin
        baseColor: "#dca487"
        roughness: 0.52
        specularAmount: 0.35
    }
    PrincipledMaterial { id: nail; baseColor: "#efc9bb"; roughness: 0.25 }
    PrincipledMaterial { id: sleeve; baseColor: "#3a3e4a"; roughness: 0.95 }

    // A rounded limb segment from `a` to `b`: a cylinder with ball ends.
    component Capsule: Node {
        id: cap
        property vector3d a
        property vector3d b
        property real r: 1
        property Material material: skin
        readonly property vector3d d: b.minus(a)
        readonly property real len: d.length()
        position: a.plus(b).times(0.5)
        rotation: {
            // turn the cylinder's Y axis to point from a to b
            const y = Qt.vector3d(0, 1, 0)
            const n = d.normalized()
            const axis = y.crossProduct(n)
            const c = Math.max(-1, Math.min(1, y.dotProduct(n)))
            if (axis.length() < 1e-5)
                return c > 0 ? Qt.quaternion(1, 0, 0, 0) : Qt.quaternion(0, 1, 0, 0)
            const half = Math.acos(c) / 2
            const k = axis.normalized().times(Math.sin(half))
            return Qt.quaternion(Math.cos(half), k.x, k.y, k.z)
        }
        Model {
            source: "#Cylinder"
            scale: Qt.vector3d(cap.r / 50, cap.len / 100, cap.r / 50)
            materials: [cap.material]
        }
        Model {
            source: "#Sphere"
            y: cap.len / 2
            scale: Qt.vector3d(cap.r / 50, cap.r / 50, cap.r / 50)
            materials: [cap.material]
        }
        Model {
            source: "#Sphere"
            y: -cap.len / 2
            scale: Qt.vector3d(cap.r / 50, cap.r / 50, cap.r / 50)
            materials: [cap.material]
        }
    }
    component Ball: Model {
        property real sx: 1
        property real sy: 1
        property real sz: 1
        source: "#Sphere"
        scale: Qt.vector3d(sx / 100, sy / 100, sz / 100)
        materials: [skin]
    }

    Repeater3D {
        model: 2
        Node {
            id: hand
            required property int index
            readonly property int s: index === 0 ? -1 : 1 // outward direction
            // Origin: the outer edge of the book, a bit above the bottom.
            position: Qt.vector3d(s * held.bookW / 2, -held.bookH / 2 + 9, 0)
            function v(x, y, z) { return Qt.vector3d(hand.s * x, y, z) }

            // Palm behind the cover, its heel showing past the edge.
            Ball { position: hand.v(1.0, -2.5, -3.2); sx: 8; sy: 9.4; sz: 3.0 }
            Ball { position: hand.v(2.2, -6.4, -2.8); sx: 5.2; sy: 4.4; sz: 3.4 } // heel of the hand

            // Four fingers curling under the cover, towards the spine.
            Repeater3D {
                model: 4
                Node {
                    required property int index
                    readonly property real y0: 1.5 - index * 2.3
                    readonly property real lenScale: [0.92, 1, 0.97, 0.82][index]
                    Capsule { a: hand.v(0.5, parent.y0, -3.6); b: hand.v(-3.8 * parent.lenScale, parent.y0 + 0.4, -3.4); r: 0.95 }
                    Capsule { a: hand.v(-3.8 * parent.lenScale, parent.y0 + 0.4, -3.4); b: hand.v(-6.6 * parent.lenScale, parent.y0 + 0.6, -2.7); r: 0.85 }
                    Capsule { a: hand.v(-6.6 * parent.lenScale, parent.y0 + 0.6, -2.7); b: hand.v(-8.4 * parent.lenScale, parent.y0 + 0.6, -1.9); r: 0.75 }
                }
            }

            // Thumb: from the palm, round the edge of the book, onto the page.
            Ball { position: hand.v(1.2, -4.6, -0.9); sx: 3.4; sy: 4.6; sz: 3.0 } // thumb muscle
            Capsule { a: hand.v(1.0, -4.2, -0.2); b: hand.v(-1.2, -2.0, 1.1); r: 0.95 }
            Capsule { a: hand.v(-1.2, -2.0, 1.1); b: hand.v(-3.4, -0.2, 0.95); r: 0.82 }
            Ball { position: hand.v(-3.5, -0.05, 1.6); sx: 1.15; sy: 0.95; sz: 0.25; materials: [nail]; eulerRotation.z: hand.s * -40 }
            Ball { position: hand.v(-1.2, -2.0, 1.55); sx: 1.5; sy: 0.5; sz: 0.2; eulerRotation.z: hand.s * -40 } // knuckle crease

            // Wrist and forearm coming up from below, then the sleeve.
            Capsule { a: hand.v(2.2, -7.4, -2.6); b: hand.v(4.2, -16.5, 2.0); r: 2.2 }
            Capsule { a: hand.v(4.2, -16.5, 2.0); b: hand.v(7.0, -34, 9.5); r: 2.7 }
            Capsule { a: hand.v(5.0, -21, 3.6); b: hand.v(8.4, -42, 14); r: 3.5; material: sleeve }
            Model { // cuff
                source: "#Cylinder"
                position: hand.v(4.9, -20.3, 3.3)
                eulerRotation: Qt.vector3d(28, 0, hand.s * -9)
                scale: Qt.vector3d(0.074, 0.018, 0.074)
                materials: PrincipledMaterial { baseColor: "#2c2f39"; roughness: 0.95 }
            }
        }
    }
}
