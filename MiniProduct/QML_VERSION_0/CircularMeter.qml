import QtQuick 6.9

Item {
    id: circularMeter

    // === Properties ===
    property string title: ""
    property real maxValue: 100
    property real value: 0
    property string unit: ""
    property real scale: 1.0
    property color needleColor: "#ff0000"
    property color backgroundColor: "transparent"
    property color tickColor: "#ffffff"
    property real step: 10
    property real subStep: step / 2
    property string mode: 'normal'    // 🌸 new feature toggle

    width: 300 * scale
    height: 300 * scale

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var cx = width / 2;
            var cy = height / 2;
            var radius = width / 2 - 10;

            // === FLOWER-LIKE MODE ===
            if (mode=='submarine') {
                var petals = Math.floor(maxValue / step);   // e.g. 200/40 = 5 petals
                var angleStep = 2 * Math.PI / petals;
                var petalRadius = radius * 0.7;
                var activePetals = Math.floor((value / maxValue) * petals);

                function drawPetal(tilt, isActive) {
                    ctx.save();

                    // Move origin to the flower center
                    ctx.translate(cx, cy);
                    // Rotate canvas for the current petal angle
                    ctx.rotate(tilt - Math.PI / 4);

                    // === start drawing exactly as the turtle does ===
                    ctx.beginPath();
                    ctx.moveTo(0, 0);

                    // The turtle’s first arc is drawn offset from current heading
                    // Move outward so the arcs aren't centered on the origin
                    ctx.translate(petalRadius / 2, 0);

                    // First quarter-circle arc (to the right)
                    ctx.arc(0, 0, petalRadius, 0, Math.PI / 2, false);

                    // Left 90° turn in turtle = rotate canvas by +90°
                    ctx.rotate(Math.PI / 2);

                    // Second quarter-circle arc
                    ctx.arc(0, 0, petalRadius, 0, Math.PI / 2, false);

                    ctx.closePath();

                    ctx.fillStyle = isActive ? needleColor : Qt.rgba(0.2, 0.2, 0.2, 0.3);
                    ctx.fill();

                    ctx.strokeStyle = tickColor;
                    ctx.lineWidth = 1.5;
                    ctx.stroke();

                    ctx.restore();
                }

                // Draw all petals, one per level
                for (var i = 0; i < petals; i++) {
                    var tilt = i * angleStep;
                    var isActive = i < activePetals;
                    drawPetal(tilt, isActive);

                    // Label at petal tip (outermost point)
                    var labelValue = (i + 1) * step;
                    var labelAngle = tilt;
                    var labelDist = petalRadius * 1.4;
                    ctx.font = (12 * scale) + "px sans-serif";
                    ctx.fillStyle = tickColor;
                    ctx.textAlign = "center";
                    ctx.fillText(labelValue,
                                 cx + labelDist * Math.cos(labelAngle),
                                 cy + labelDist * Math.sin(labelAngle) + 4);
                }

                // Center circle
                ctx.beginPath();
                ctx.arc(cx, cy, radius * 0.15, 0, 2 * Math.PI);
                ctx.fillStyle = backgroundColor !== "transparent" ? backgroundColor : "#333";
                ctx.fill();

                // Needle (points based on value)
                var valAngle = (value / maxValue) * 2 * Math.PI;
                ctx.beginPath();
                ctx.moveTo(cx, cy);
                ctx.lineTo(cx + (radius - 20) * Math.cos(valAngle),
                           cy + (radius - 20) * Math.sin(valAngle));
                ctx.strokeStyle = needleColor;
                ctx.lineWidth = 3;
                ctx.stroke();

                // Current value label
                ctx.font = "bold " + (20 * scale) + "px sans-serif";
                ctx.fillStyle = tickColor;
                ctx.textAlign = "center";
                ctx.fillText(Math.round(value) + " " + unit, cx, cy + 8);
            }


            // === NORMAL ROUND METER ===
            else {
                // Background
                if (backgroundColor !== "transparent") {
                    ctx.beginPath();
                    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                    ctx.fillStyle = backgroundColor;
                    ctx.fill();
                }

                // Outer circle
                ctx.beginPath();
                ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                ctx.strokeStyle = tickColor;
                ctx.lineWidth = 2;
                ctx.stroke();

                // Major ticks + labels
                for (var i = 0; i <= maxValue; i += step) {
                    var angle = Math.PI * (0.75 - (i / maxValue) * 1.5);
                    var x1 = cx + (radius - 10) * Math.cos(angle);
                    var y1 = cy - (radius - 10) * Math.sin(angle);
                    var x2 = cx + radius * Math.cos(angle);
                    var y2 = cy - radius * Math.sin(angle);
                    ctx.beginPath();
                    ctx.moveTo(x1, y1);
                    ctx.lineTo(x2, y2);
                    ctx.strokeStyle = tickColor;
                    ctx.lineWidth = 2;
                    ctx.stroke();

                    // Label
                    ctx.font = (12 * scale) + "px sans-serif";
                    ctx.fillStyle = tickColor;
                    ctx.textAlign = "center";
                    ctx.fillText(i, cx + (radius - 25) * Math.cos(angle),
                                    cy - (radius - 25) * Math.sin(angle));
                }

                // Sub-ticks
                for (var i = 0; i <= maxValue; i += subStep) {
                    if (i % step === 0) continue;
                    var angle = Math.PI * (0.75 - (i / maxValue) * 1.5);
                    var x1 = cx + (radius - 6) * Math.cos(angle);
                    var y1 = cy - (radius - 6) * Math.sin(angle);
                    var x2 = cx + radius * Math.cos(angle);
                    var y2 = cy - radius * Math.sin(angle);
                    ctx.beginPath();
                    ctx.moveTo(x1, y1);
                    ctx.lineTo(x2, y2);
                    ctx.strokeStyle = tickColor;
                    ctx.lineWidth = 1;
                    ctx.stroke();
                }

                // Needle
                var valAngle = Math.PI * (0.75 - (value / maxValue) * 1.5);
                ctx.beginPath();
                ctx.moveTo(cx, cy);
                ctx.lineTo(cx + (radius - 20) * Math.cos(valAngle),
                           cy - (radius - 20) * Math.sin(valAngle));
                ctx.strokeStyle = needleColor;
                ctx.lineWidth = 3;
                ctx.stroke();
            }

            // === Center text ===
            ctx.font = "bold " + (20 * scale) + "px sans-serif";
            ctx.fillStyle = tickColor;
            ctx.textAlign = "center";
            ctx.fillText(Math.round(value) + " " + unit, cx, cy + 10);
        }
    }

    Behavior on value {
        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
    }
    onValueChanged: canvas.requestPaint()
}
