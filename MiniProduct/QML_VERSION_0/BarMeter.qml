// BarMeter.qml
import QtQuick 6.9
import QtQuick.Controls 6.9

Item {
    id: barMeterRoot

    // === Customizable properties ===
    property real value: 0                // 0–100%
    property color barColor: "#00ff00"    // fill color
    property string labelText: "Label"    // text below the bar
    property real scale: 1.0              // rescale entire component
    property real cornerRadius: width / 2

    property color backgroundColor: "#2a2a2a"


    width: 40 * scale
    height: 200 * scale
    opacity: 1.0

    // subtle shadow simulated by a rounded rectangle behind the bar
    Rectangle {
        id: shadowRect
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: parent.width * 0.9
        height: Math.max(8 * scale, parent.width * 0.25)
        y: parent.height - (height / 2)
        color: "#00000055"
        radius: height / 2
        z: 0
        // reduce visible height to make it feel like a shadow at the base
    }

    // === Background bar ===
    Rectangle {
        id: barBackground
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.height - (24 * scale)   // leave space for label below
        radius: parent.width / 2
        color: backgroundColor
        border.color: "#444"
        border.width: 1
        z: 1

        // inner bevel / light edge using gradient
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            opacity: 0.08
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1,1,1,0.06) }
                GradientStop { position: 1.0; color: Qt.rgba(0,0,0,0.06) }
            }
            z: 2
        }

        // === Fill level (animated) ===
        Rectangle {
            id: barFill
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: parent.width - 4
            height: Math.max((value / 100) * parent.height, 2)  // avoid zero-height drawing issues
            x: (parent.width - width) / 2
            radius: width / 2
            color: barColor
            z: 3

            Behavior on height {
                NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
            }

            // slight glossy highlight at top of fill
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: Math.min(16 * scale, parent.height * 0.25)
                radius: parent.radius
                opacity: 0.12
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1,1,1,0.45) }
                    GradientStop { position: 1.0; color: Qt.rgba(1,1,1,0.0) }
                }
            }
        }

        // thin tick marks on the left side (optional)
        Column {
            anchors.left: parent.left
            anchors.leftMargin: 3
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            spacing: parent.height / 6
            Repeater { model: 5
                Rectangle { width: 2; height: 6 * scale; color: "#111"; radius: 1; opacity: 0.4 }
            }
            z: 4
        }
    }

    // === Numeric value overlay (centered) ===
    Text {
        id: valueText
        text: Math.round(value) + "%"
        anchors.horizontalCenter: barBackground.horizontalCenter
        anchors.verticalCenter: barBackground.verticalCenter
        font.pixelSize: 12 * scale
        color: "#f0f0f0"
        opacity: 0.9
        z: 10
    }

    // === Label text below the bar ===
    Text {
        id: barLabel
        // text: labelText
        anchors.top: barBackground.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 6 * scale
        font.pixelSize: 14 * scale
        color: "white"
        font.bold: true
        z: 10
    }

    // optional simple fade-in transition for the whole component
    Behavior on opacity {
        NumberAnimation { duration: 350; easing.type: Easing.InOutQuad }
    }
}
