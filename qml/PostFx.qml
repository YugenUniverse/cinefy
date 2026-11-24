import QtQuick
import QtQuick.Effects

// Post-processing for the 3D picture (used as a layer effect): bloom from the
// bright parts, then colour grade, vignette and grain.
Item {
    id: fx
    property var source // set by the layer
    property real bloomStrength: 0.9
    // the glow only comes in once its first frames are real
    property real ramp: 0
    NumberAnimation on ramp { from: 0; to: 1; duration: 1200; easing.type: Easing.InQuad }
    property real time: 0
    NumberAnimation on time { from: 0; to: 100; duration: 100000; loops: Animation.Infinite }

    ShaderEffect {
        id: bright
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.textureSize: Qt.size(Math.max(1, width / 4), Math.max(1, height / 4)) // glow is soft: low-res is fine
        property var source: fx.source
        property real threshold: 0.86 // only real light sources, not white paper
        fragmentShader: "qrc:/qt/qml/Cinefy/qml/shaders/bright.frag.qsb"
    }
    MultiEffect {
        id: blurred
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.textureSize: Qt.size(Math.max(1, width / 4), Math.max(1, height / 4))
        source: bright
        autoPaddingEnabled: false // keep the glow exactly on top of what glows
        blurEnabled: true
        blur: 1.0
        blurMax: 48
        blurMultiplier: 1.4
    }
    ShaderEffect {
        anchors.fill: parent
        property var source: fx.source
        property var bloom: blurred
        property real bloomStrength: fx.bloomStrength * fx.ramp
        property real time: fx.time
        property size resolution: Qt.size(width, height)
        fragmentShader: "qrc:/qt/qml/Cinefy/qml/shaders/grade.frag.qsb"
    }
}
