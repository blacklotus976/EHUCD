import QtQuick
import QtQuick.Controls

Item {
    id: area
    property int mode: 1
    property bool isAuthenticating: false
    property bool isError: false
    property var mouseSource: null

    // --- NEW DYNAMIC SCALING FOR CREATURES ---
    // This matches your main window's logic
    readonly property real baseWidth: 900
    readonly property real creatureScale: {
        let ratio = area.width / (900 * (4/7)); // Scale relative to their panel width
        return ratio < 1.0 ? ratio : 1.0 + (ratio - 1.0) * 0.5;
    }

    clip: true

    Timer {
        id: physicsLoop
        interval: 16
        running: mode > 0 && !root.isResizing
        repeat: true
        onTriggered: {
            if (mode !== 2) return;

            var items = []
            for (var i = 0; i < creatureRepeater.count; i++) {
                var item = creatureRepeater.itemAt(i)
                if (item) items.push(item)
            }

            for (var i = 0; i < items.length; i++) {
                var c = items[i]

                // 1. CALM MOVEMENT (Reduced speed multiplier from 0.3 to 0.15)
                c.vx *= 0.99; c.vy *= 0.99
                c.x += c.vx * 0.15; c.y += c.vy * 0.15

                // 2. SOFT WALL BOUNCES (Reduced "push" from 2 to 0.5)
                if (c.x <= 0) { c.x = 2; c.vx = Math.abs(c.vx) + 0.5; }
                else if (c.x + c.width >= width) { c.x = width - c.width - 2; c.vx = -Math.abs(c.vx) - 0.5; }
                if (c.y <= 0) { c.y = 2; c.vy = Math.abs(c.vy) + 0.5; }
                else if (c.y + c.height >= height) { c.y = height - c.height - 2; c.vy = -Math.abs(c.vy) - 0.5; }

                // 3. MINIMUM SPEED (Lowered from 3.0 to 1.0 for a "floaty" feel)
                var speed = Math.sqrt(c.vx*c.vx + c.vy*c.vy)
                if (speed < 1.0) {
                    var ang = Math.atan2(c.vy, c.vx)
                    c.vx = Math.cos(ang) * 1.5; c.vy = Math.sin(ang) * 1.5
                }

                // 4. BOSS COLLISION
                var dxM = (c.x + c.width/2) - (mainCreature.x + mainCreature.width/2)
                var dyM = (c.y + c.width/2) - (mainCreature.y + mainCreature.height/2)
                var distM = Math.sqrt(dxM*dxM + dyM*dyM)
                var minDistM = (c.width/2 + mainCreature.width/2)
                if (distM < minDistM) {
                    var angM = Math.atan2(dyM, dxM)
                    c.vx = Math.cos(angM) * 3; c.vy = Math.sin(angM) * 3
                    c.x = (mainCreature.x + mainCreature.width/2) + Math.cos(angM) * minDistM - c.width/2
                    c.y = (mainCreature.y + mainCreature.height/2) + Math.sin(angM) * minDistM - c.height/2
                }

                // 5. INTER-CREATURE COLLISION (Softened overlap push)
                for (var j = i + 1; j < items.length; j++) {
                    var c2 = items[j]
                    var dx = (c2.x + c2.width/2) - (c.x + c.width/2)
                    var dy = (c2.y + c2.height/2) - (c.y + c.height/2)
                    var distance = Math.sqrt(dx*dx + dy*dy)
                    var minDistance = (c.width/2 + c2.width/2)

                    if (distance < minDistance) {
                        var collisionAngle = Math.atan2(dy, dx)
                        var tempVx = c.vx; var tempVy = c.vy
                        c.vx = c2.vx; c.vy = c2.vy
                        c2.vx = tempVx; c2.vy = tempVy

                        // PUSH APART (Reduced from /2 to /4 for less "vibration")
                        var overlap = minDistance - distance
                        var moveX = Math.cos(collisionAngle) * (overlap / 4)
                        var moveY = Math.sin(collisionAngle) * (overlap / 4)
                        c.x -= moveX; c.y -= moveY
                        c2.x += moveX; c2.y += moveY
                    }
                }
            }
        }
    }

    Repeater {
        id: creatureRepeater
        model: area.mode === 2 ? 12 : 0
        delegate: Creature {
            // Apply scale here
            size: (Math.random() * 30 + 40) * area.creatureScale
            x: Math.random() * (area.width - 100); y: Math.random() * (area.height - 100)
            bodyColor: Qt.rgba(Math.random(), Math.random(), Math.random(), 1)
            expression: area.isAuthenticating ? 1 : (area.isError ? -1 : 0)
            property real vx: (Math.random() - 0.5) * 5 // Slower initial burst
            property real vy: (Math.random() - 0.5) * 5
        }
    }

    Creature {
        id: mainCreature
        // Apply scale to the boss
        size: 160 * area.creatureScale
        anchors.centerIn: parent
        visible: area.mode > 0
        bodyColor: "#e67e22"; z: 100
        expression: area.isAuthenticating ? 1 : (area.isError ? -1 : 0)
    }

    // Creature component remains mostly the same, width/height now use 'size' which is scaled
    component Creature : Rectangle {
        id: creatureRoot
        property real size: 100
        property color bodyColor: "orange"
        property int expression: 0
        width: size; height: size; radius: size/2; color: bodyColor

        // ... (Eyes and Mouth code remain the same as they use relative 'size' units) ...
        Row {
            anchors.centerIn: parent; anchors.verticalCenterOffset: -size * 0.1; spacing: size * 0.12
            Repeater {
                model: 2
                Rectangle {
                    id: white; width: creatureRoot.size * 0.22; height: width; radius: width/2; color: "white"
                    Rectangle {
                        id: pupil; width: parent.width * 0.5; height: width; radius: width/2; color: "black"
                        anchors.centerIn: parent
                        property var m: mouseSource ? pupil.mapFromItem(mouseSource, mouseSource.mouseX, mouseSource.mouseY) : {"x":0, "y":0}
                        property real angle: Math.atan2(m.y, m.x)
                        property real dist: Math.sqrt(m.x*m.x + m.y*m.y)
                        property real limit: (white.width - pupil.width)/2 - 1
                        transform: Translate {
                            x: Math.cos(pupil.angle) * Math.min(pupil.dist, pupil.limit)
                            y: Math.sin(pupil.angle) * Math.min(pupil.dist, pupil.limit)
                        }
                    }
                }
            }
        }
        Canvas {
            id: mouthCanvas; anchors.fill: parent; opacity: expression === 0 ? 0 : 1
            property real curveValue: expression
            Behavior on curveValue { NumberAnimation { duration: 300 } }
            onCurveValueChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d"); ctx.reset(); ctx.beginPath(); ctx.lineWidth = size * 0.04;
                ctx.strokeStyle = "black"; ctx.lineCap = "round";
                var cX = width*0.5, cY = height*0.75, mW = size*0.15, bend = curveValue*(size*0.1);
                ctx.moveTo(cX-mW, cY); ctx.quadraticCurveTo(cX, cY+bend, cX+mW, cY); ctx.stroke();
            }
        }
    }
}