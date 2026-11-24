import QtQuick
import QtQuick3D

// The shop's shell (front, side and back walls, ceiling), drawn invisibly
// (depth only). Used by the rain layer: drops behind the shop, or seen from
// inside through a wall or the ceiling, are hidden; they still show through
// the windows and the door.
Node {
    id: front
    readonly property var store: shop.store
    readonly property Material invisible: CustomMaterial {
        shadingMode: CustomMaterial.Unshaded
        fragmentShader: "holdout.frag"
    }
    component Block: Model {
        source: "#Cube"
        materials: [front.invisible]
    }
    z: store.frontZ
    Repeater3D {
        model: 2
        Node {
            id: side
            required property int index
            readonly property int s: index === 0 ? -1 : 1
            readonly property real inner: store.doorHalfWidth
            readonly property real span: store.halfWidth - inner
            Block { // sill
                position: Qt.vector3d(side.s * (side.inner + side.span / 2), 35, 0)
                scale: Qt.vector3d(side.span / 100, 0.7, 0.3)
            }
            Block { // header, awning height and up
                position: Qt.vector3d(side.s * (side.inner + side.span / 2), 360, 0)
                scale: Qt.vector3d(side.span / 100, 2.4, 0.3)
            }
            Block { // pillars
                position: Qt.vector3d(side.s * (side.inner + 15), 155, 0)
                scale: Qt.vector3d(0.3, 1.7, 0.3)
            }
            Block {
                position: Qt.vector3d(side.s * (store.halfWidth - 15), 155, 0)
                scale: Qt.vector3d(0.3, 1.7, 0.3)
            }
        }
    }
    Block { // above the door
        position: Qt.vector3d(0, 360, 0)
        scale: Qt.vector3d(store.doorHalfWidth * 2 / 100, 2.4, 0.3)
    }
    Block { // the canopy band keeps the pavement under it dry
        position: Qt.vector3d(0, 332, 45)
        scale: Qt.vector3d((store.halfWidth * 2 + 40) / 100, 1.24, 0.9)
    }
    // Side walls, back wall and ceiling, up to the top of the shop front.
    Block {
        position: Qt.vector3d(-store.halfWidth - 8, 240, (store.backZ - store.frontZ) / 2)
        scale: Qt.vector3d(0.16, 4.8, (store.frontZ - store.backZ) / 100)
    }
    Block {
        position: Qt.vector3d(store.halfWidth + 8, 240, (store.backZ - store.frontZ) / 2)
        scale: Qt.vector3d(0.16, 4.8, (store.frontZ - store.backZ) / 100)
    }
    Block {
        position: Qt.vector3d(0, 240, store.backZ - store.frontZ - 8)
        scale: Qt.vector3d(store.halfWidth * 2 / 100, 4.8, 0.16)
    }
    Block {
        position: Qt.vector3d(0, 332, (store.backZ - store.frontZ) / 2 - 8)
        scale: Qt.vector3d(store.halfWidth * 2 / 100 + 0.2, 0.04, (store.frontZ - store.backZ) / 100)
    }
    Repeater3D { // the posters taped inside the windows
        model: Math.min(store.windowPosters.length, shop.windowPosters.length)
        Block {
            required property int index
            readonly property var spot: store.windowPosters[index]
            position: Qt.vector3d(spot.x, spot.y, -1.6)
            eulerRotation.z: spot.tilt
            scale: Qt.vector3d(spot.w / 100, spot.h / 100, 0.004)
        }
    }
    Block { // the sign on the roof
        position: Qt.vector3d(-40, 520, 30)
        scale: Qt.vector3d(5.4, 1.2, 0.02)
    }
}
