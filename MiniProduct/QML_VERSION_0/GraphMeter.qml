import QtQuick 6.9

Item {
    id: graphMeter
    width: 400
    height: 180

    // === Public API ===
    property string title: "Metric"
    property real value: 0
    property string unit: ""
    property color lineColor: "#00ffaa"
    property color fillColor: "#003322"
    property color textColor: "#ffffff"
    property int maxValue: 150          // hard cap for vertical scale
    property int maxSamples: 100        // how many points to remember
    property real smoothFactor: 0.2     // 0=no smoothing, 1=instant follow

    // === Internal rolling buffer ===
    property var values: []
    property real displayedValue: 0

    onValueChanged: {
        const v = Math.min(value, maxValue)
        values.push(v)
        if (values.length > maxSamples)
            values.shift()
        canvas.requestPaint()
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: "#121212"
        border.color: "#333"
    }

    // === Title ===
    Text {
        id: titleLabel
        text: graphMeter.title
        color: textColor
        font.pixelSize: 16
        font.bold: true
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.top: parent.top
        anchors.topMargin: 4
    }

    // === Canvas Graph ===
    Canvas {
        id: canvas
        anchors.top: titleLabel.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)

            if (values.length < 2)
                return

            // Smooth transition for visual continuity
            graphMeter.displayedValue += (values[values.length - 1] - graphMeter.displayedValue) * graphMeter.smoothFactor

            const maxV = graphMeter.maxValue
            const minV = 0
            const dx = width / (values.length - 1)

            // Background grid lines
            ctx.strokeStyle = "#222"
            ctx.lineWidth = 1
            for (let i = 0; i <= 5; i++) {
                const y = height - (i / 5) * height
                ctx.beginPath()
                ctx.moveTo(0, y)
                ctx.lineTo(width, y)
                ctx.stroke()
            }

            // Map value to Y coordinate
            function mapY(v) {
                return height - Math.max(0, Math.min(v, maxV)) / maxV * height
            }

            // Fill under curve
            ctx.beginPath()
            ctx.moveTo(0, mapY(values[0]))
            for (let i = 1; i < values.length; i++)
                ctx.lineTo(i * dx, mapY(values[i]))
            ctx.lineTo(width, height)
            ctx.lineTo(0, height)
            ctx.closePath()
            ctx.fillStyle = fillColor
            ctx.globalAlpha = 0.35
            ctx.fill()
            ctx.globalAlpha = 1.0

            // Main line
            ctx.beginPath()
            ctx.moveTo(0, mapY(values[0]))
            for (let i = 1; i < values.length; i++)
                ctx.lineTo(i * dx, mapY(values[i]))
            ctx.strokeStyle = lineColor
            ctx.lineWidth = 2
            ctx.lineJoin = "round"
            ctx.stroke()

            // Current value label bubble
            const lastY = mapY(values[values.length - 1])
            const lastX = width - 6
            const label = Math.round(graphMeter.displayedValue) + (unit !== "" ? " " + unit : "")

            const textWidth = ctx.measureText(label).width
            const pad = 4

            ctx.fillStyle = "rgba(0,0,0,0.6)"
            ctx.fillRect(lastX - textWidth - pad * 2, lastY - 16, textWidth + pad * 2, 18)

            ctx.fillStyle = textColor
            ctx.font = "bold 13px 'Segoe UI', sans-serif"
            ctx.textAlign = "right"
            ctx.fillText(label, lastX - pad, lastY - 2)
        }
    }

    // === Animated repaint for smoothness ===
    Timer {
        interval: 120
        running: true
        repeat: true
        onTriggered: canvas.requestPaint()
    }
}
