import QtQuick
import QtQuick3D

// The umbrella you hold out on the street, seen from underneath: a striped
// canopy above your head and the shaft in your hand. `open` goes 0 → 1.
Node {
    id: umbrella
    property real open: 1

    component Fabric: PrincipledMaterial {
        roughness: 0.75
        cullMode: Material.NoCulling // we look at the underside
    }

    Node {
        y: 66
        Model {
            geometry: UmbrellaGeometry { parity: 0; open: umbrella.open }
            materials: Fabric { baseColor: "#b51f2a" }
        }
        Model {
            geometry: UmbrellaGeometry { parity: 1; open: umbrella.open }
            materials: Fabric { baseColor: "#ece6d6" }
        }
        Model { // tip on top
            source: "#Cylinder"
            y: 34 + (1 - umbrella.open) * 60 + 6
            scale: Qt.vector3d(0.012, 0.12, 0.012)
            materials: PrincipledMaterial { baseColor: "#2b2b2e"; metalness: 0.6; roughness: 0.4 }
        }
    }
    Model { // shaft, from the canopy down into your hand
        source: "#Cylinder"
        y: 22
        scale: Qt.vector3d(0.01, 0.95, 0.01)
        materials: PrincipledMaterial { baseColor: "#3a3a3e"; metalness: 0.7; roughness: 0.35 }
    }
    Model { // wooden handle
        source: "#Cylinder"
        y: -30
        scale: Qt.vector3d(0.03, 0.16, 0.03)
        materials: PrincipledMaterial { baseColor: "#6b3f22"; roughness: 0.55 }
    }
}
