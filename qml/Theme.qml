pragma Singleton
import QtQuick

QtObject {
    readonly property color bg: "#070914"
    readonly property color navy: "#081030"
    readonly property color blue: "#1747c4"
    readonly property color yellow: "#ffd21f"
    readonly property color pink: "#ff3d9a"
    readonly property color cyan: "#3df5ff"
    readonly property color red: "#e6332a"
    readonly property color text: "#f6f1e3"
    readonly property color dim: "#9aa3c0"
    readonly property color line: "#3a4470"
    readonly property color wood: "#6b4426"
    readonly property color woodLight: "#8a5a32"
    readonly property color woodDark: "#3f2714"

    // Pick fonts that exist on this system: Linux, Windows or macOS.
    function pick(preferred, fallback) {
        const installed = Qt.fontFamilies()
        for (const f of preferred)
            if (installed.indexOf(f) >= 0)
                return f
        return fallback
    }
    readonly property string body: pick(["Noto Sans", "DejaVu Sans", "Segoe UI", "Helvetica Neue", "Arial"],
                                        Qt.application.font.family)
    readonly property string display: body
    readonly property string mono: pick(["DejaVu Sans Mono", "Noto Sans Mono", "Consolas", "Menlo", "Courier New"],
                                        "monospace")

    function stars(r) {
        if (!r || r <= 0)
            return ""
        const full = Math.floor(r)
        return "★".repeat(full) + (r - full >= 0.5 ? "½" : "")
    }
}
