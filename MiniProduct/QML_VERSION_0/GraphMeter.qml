import QtQuick 6.9

Item {
    id: graphMeter

    // === Public API ===
    property string title: "RPM"
    property real value: 0
    property string unit: ""
    property color lineColor: "#0088ff"
    property color fillColor: "#d0ecff"
    property  int maxValue: 200
    property color textColor: "#004477"
    property int maxSamples: 40

    // internal rolling buffer
    property var values: []

    onValueChanged: {
        values.push(value);
        if (values.length > maxSamples)
            values.shift();
        canvas.requestPaint();
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: "white"
        border.color: "#cccccc"
    }

    // TITLE (auto-resizes based on available width)
    Text {
        id: titleLabel
        text: graphMeter.title
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 6
        anchors.topMargin: 4
        font.pixelSize: Math.max(10, graphMeter.height * 0.12)
        font.bold: true
        color: textColor
    }

    Canvas {
        id: canvas
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.top: titleLabel.bottom
        anchors.topMargin: 4
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        anchors.bottomMargin: 4

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);

            if (values.length < 2)
                return;

            var minVal = Math.min.apply(Math, values);
            var maxVal = Math.max.apply(Math, values);
            if (minVal === maxVal)
                maxVal = minVal + 1;

            function mapY(v) {
                return height - ((v - minVal) / (maxVal - minVal)) * height;
            }

            var dx = width / (values.length - 1);

            // UNDER-FILL
            ctx.beginPath();
            ctx.moveTo(0, mapY(values[0]));
            for (var i = 1; i < values.length; i++)
                ctx.lineTo(i * dx, mapY(values[i]));
            ctx.lineTo(width, height);
            ctx.lineTo(0, height);
            ctx.closePath();
            ctx.fillStyle = fillColor;
            ctx.globalAlpha = 0.45;
            ctx.fill();
            ctx.globalAlpha = 1.0;

            // MAIN CURVE
            ctx.beginPath();
            ctx.moveTo(0, mapY(values[0]));
            for (var i = 1; i < values.length; i++)
                ctx.lineTo(i * dx, mapY(values[i]));
            ctx.strokeStyle = lineColor;
            ctx.lineWidth = Math.max(2, graphMeter.width * 0.06);
            ctx.lineJoin = "round";
            ctx.stroke();

            // FLOAT VALUE LABEL
            var lx = width - 2;
            var ly = mapY(values[values.length - 1]);

            ctx.fillStyle = textColor;
            ctx.font = "bold " + Math.max(10, graphMeter.height * 0.15) + "px sans-serif";
            ctx.textAlign = "left";

            var label = Math.round(value);
            if (unit !== "") label += " " + unit;

            ctx.fillText(label, lx + 6, ly);
        }
    }
}
