import QtQuick

// The loud 90s cinema carpet: confetti shapes on navy, drawn once per size.
Canvas {
    id: carpet
    property color base: "#0b0f2e"

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.fillStyle = base
        ctx.fillRect(0, 0, width, height)

        let seed = 1987
        function rnd() {
            seed = (seed * 16807) % 2147483647
            return (seed - 1) / 2147483646
        }
        const colors = ["#ff3d9a", "#3df5ff", "#ffd21f", "#7b5cff"]
        const count = Math.floor(width * height / 2400)
        ctx.lineWidth = 3
        ctx.lineCap = "round"
        for (let i = 0; i < count; ++i) {
            const x = rnd() * width, y = rnd() * height
            const s = 6 + rnd() * 12
            const kind = Math.floor(rnd() * 4)
            const col = colors[Math.floor(rnd() * colors.length)]
            ctx.globalAlpha = 0.16 + rnd() * 0.22
            ctx.strokeStyle = col
            ctx.fillStyle = col
            ctx.beginPath()
            if (kind === 0) {
                ctx.arc(x, y, s / 3, 0, Math.PI * 2)
                ctx.fill()
            } else if (kind === 1) {
                ctx.moveTo(x, y)
                ctx.lineTo(x + s, y + s * 0.3)
                ctx.lineTo(x + s * 0.2, y + s)
                ctx.closePath()
                ctx.stroke()
            } else if (kind === 2) {
                ctx.moveTo(x, y)
                ctx.bezierCurveTo(x + s * 0.5, y - s * 0.6, x + s * 0.5, y + s * 0.6, x + s, y)
                ctx.stroke()
            } else {
                ctx.rect(x, y, s * 0.5, s * 0.5)
                ctx.stroke()
            }
        }
        ctx.globalAlpha = 1
    }
}
