import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: window
    width: 1440
    height: 900
    minimumWidth: 980
    minimumHeight: 660
    visible: true
    title: "Cinefy Video"
    color: Theme.bg

    // Qt Quick 3D can crash if the 3D scene is still alive while the app shuts
    // down, so every way out unloads the shop first and quits a moment later.
    // Three steps, so the render thread is never mid-frame on a 3D view that
    // is being destroyed: stop drawing 3D, unload it, then quit.
    property bool closing: false   // 3D hidden: no more 3D frames
    property bool quitting: false  // store unloaded
    function quitApp() {
        if (closing)
            return
        closing = true
        unloadTimer.start()
    }
    Timer {
        id: unloadTimer
        interval: 250
        onTriggered: { window.quitting = true; quitTimer.start() }
    }
    Timer {
        id: quitTimer
        interval: 300
        onTriggered: Qt.quit()
    }
    onClosing: close => {
        if (!closing) {
            close.accepted = false
            quitApp()
        }
    }

    Loader {
        anchors.fill: parent
        sourceComponent: window.quitting ? null : shop.loaded ? shopFloor : storefront
    }

    Component { id: storefront; Storefront {} }
    Component { id: shopFloor; Store3D {} }

    Shortcut {
        sequences: [StandardKey.Quit, "Ctrl+Q"]
        context: Qt.ApplicationShortcut
        onActivated: window.quitApp()
    }
}
