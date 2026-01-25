import QtQuick 6.9
import QtQuick.Controls 6.9

Item {
    id: barMeterRoot

    // === Customizable public properties ===
    property real value: 0                  // Current value (raw units)
    property real maxValue: 100             // Maximum value before capping
    property string unit: '' //"%"               // Display unit (default "%")
    property color barColor: "#00ff00"      // Fill color
    property color backgroundColor: "#2a2a2a"
    property string labelText: "Label"      // Text under the bar
    property real scale: 1.0                // Rescale component size

    width: 40 * scale
    height: 200 * scale
    opacity: 1.0

    // --- subtle base shadow ---
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
    }

    // === Main bar background ===
    Rectangle {
        id: barBackground
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.height - (24 * scale)
        radius: parent.width / 2
        color: backgroundColor
        border.color: "#444"
        border.width: 1
        z: 1

        // inner bevel
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
            radius: width / 2
            z: 3

            // Compute capped height
            property real normalized: Math.min(value / maxValue, 1.0)
            height: Math.max(normalized * barBackground.height, 2)

            color: barColor
            x: (parent.width - width) / 2

            Behavior on height {
                NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
            }

            // glossy highlight
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

        // optional tick marks
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

    // === Numeric value overlay ===
    Text {
        id: valueText
        text: Math.round(value) + (unit ? unit : "")

        anchors.horizontalCenter: barBackground.horizontalCenter
        anchors.verticalCenter: barBackground.verticalCenter
        font.pixelSize: 13 * scale
        color: "#f0f0f0"
        opacity: 0.95
        font.bold: true
        z: 10
    }

    // === Label below the bar ===
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

    // fade-in for the whole component
    Behavior on opacity {
        NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
    }
}
