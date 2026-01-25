import QtQuick 6.9
import QtQuick.Controls 6.9
import QtQuick.Layouts 6.9
import QtQuick.Shapes 6.9
import QtQuick.Effects 6.9
import QtQuick.Dialogs 6.9
import QtQuick.Controls.Material 6.9
import "core"



Item {
    id: root
    width: 900
    height: 600
    // visible: true
    // title: "Car Dashboard"

    Material.theme: Material.Dark
    Material.accent: Material.Green

    property var navigator
    property var carMetrics

    property var colorOptions: []  // Initialize as an empty array


    function getColorValue(colorName) {
        var colorObj = colorOptions.find(elem => elem.name === colorName);
        return colorObj ? colorObj.value : "transparent"; // Default to transparent if not found
    }

    property color speedNeedleColor: '#FFFFFF'
    property color speedBgColor: '#FFFFFF'
    property color speedTickColor: '#FFFFFF'
    property color rpmNeedleColor: '#FFFFFF'
    property color rpmBgColor: '#FFFFFF'
    property color rpmTickColor: '#FFFFFF'
    property color barBgColor: '#FFFFFF'
    property color barColor: '#FFFFFF'
    property color metricBoxColor: '#FFFFFF'


    property string speedDesign: "circular"
    property string rpmDesign: "circular"
    property string fuelDesign: "circular"
    property string throttleDesign: "bar"
    property string brakeDesign: "bar"

    Component.onCompleted: {
        colorOptions = carMetrics.get_dynamic_colors();
        console.log("Initialized Color Options: ", colorOptions);

        const colors = carMetrics.read_color_settings();

        if (colors.length === 9) {  // Check if the expected number of colors is returned
            speedNeedleColor = getColorValue(colors[0]);
            speedBgColor = getColorValue(colors[1]);
            speedTickColor = getColorValue(colors[2]);
            rpmNeedleColor = getColorValue(colors[3]);
            rpmBgColor = getColorValue(colors[4]);
            rpmTickColor = getColorValue(colors[5]);
            barBgColor = getColorValue(colors[6]);
            barColor = getColorValue(colors[7]);
            metricBoxColor = getColorValue(colors[8]);
        } else {
            console.log("Expected 8 colors, but got: " + colors.length);
        }
        var d = carMetrics.read_design_settings()
        // ✅ read live from config backend
        speedDesign = configBackend.get("SPEED_DESIGN")
        rpmDesign = configBackend.get("RPM_DESIGN")
        fuelDesign = configBackend.get("FUEL_DESIGN")

        console.log("Designs loaded from config:",
                    speedDesign, rpmDesign, fuelDesign)

        throttleDesign = d[3]
        brakeDesign = d[4]

    }




    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#004d00" }
            GradientStop { position: 1.0; color: "#00aa00" }
        }
    }

    // --- SETTINGS BUTTON ---
    Button {
        id: settingsBtn
        text: "⚙ Settings"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 10
        onClicked: mainSettingsDialog.open()
    }

    // --- POWER BUTTON ---
    Button {
        id: offBtn
        text: "⏻ Power Off"
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        onClicked: {}
    }

    // --- MUSIC BUTTON ---
    Button {
        id: musicScreenBtn
        text: "♪♫ Music"
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 10
        width: 100
        height: 32
        onClicked: {
            if (navigator && typeof navigator.changeScreen === "function")
                navigator.changeScreen("music")
            else console.warn("Navigator not found for Music")
        }
    }

    // --- LOG BUTTON ---
    Button {
        id: logBtn
        text: carMetrics.isLogging ? "Stop Logging" : "Start Logging"
        anchors.top: parent.top
        anchors.left: musicScreenBtn.right
        anchors.leftMargin: 10
        anchors.topMargin: 10
        width: 120
        height: 32
        onClicked: {
            if (carMetrics) {
                carMetrics.toggleLogging()
            }
        }
         Connections {
            target: carMetrics
            function onLoggingStateChanged(state) {
                logBtn.text = state ? "Stop Logging" : "Start Logging"
            }
        }
    }

    // --- MAPS BUTTON ---
    Button {
        id: mapsBtn
        text: "MAPS"
        anchors.top: parent.top
        anchors.left: logBtn.right
        anchors.leftMargin: 10
        anchors.topMargin: 10
        width: 80
        height: 32
        onClicked: {
            if (navigator && typeof navigator.changeScreen === "function")
                navigator.changeScreen("maps")
            else console.warn("Navigator not found for MAPS")
        }
    }

    // --- DTC INFO BUTTON ---
    Button {
        id: dtcBtn
        text: "DTC & Info"
        anchors.top: parent.top
        anchors.left: mapsBtn.right
        anchors.leftMargin: 10
        anchors.topMargin: 10
        width: 100
        height: 32
        onClicked: {
            if (navigator && typeof navigator.changeScreen === "function")
                navigator.changeScreen("dtc&info")
            else console.warn("Navigator not found for DTCInfo")
        }
    }




    Dialog {
        id: mainSettingsDialog
        title: "Settings"
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel

        contentItem: Column {
            spacing: 8
            padding: 12

            // Main options
            Button {
                text: "Color Options"
                onClicked: colorSettingsDialog.open()  // Directly open the dialog here
            }
            Button {
                text: "System Options"
                onClicked: {} // No action for now
            }
            Button {
                text: "System Design Options"
                onClicked: {} // No action for now
            }
        }
    }

    // Color Settings Dialog
    // Color Settings Dialog Instance
    ColorSettingsDialog {
        id: colorSettingsDialog
        colorOptionsHere: colorOptions
        speedNeedleColor: root.speedNeedleColor
        speedBgColor: root.speedBgColor
        speedTickColor: root.speedTickColor
        rpmNeedleColor: root.rpmNeedleColor
        rpmBgColor: root.rpmBgColor
        rpmTickColor: root.rpmTickColor
        barColor: root.barColor
        barBgColor: root.barBgColor
        metricBoxColor: root.metricBoxColor
    }



    // --- MAIN DASHBOARD LAYOUT ---
    // =============================================================
    // =============================================================
    // MAIN DASHBOARD LAYOUT (fixed + compact + full component restore)
    // =============================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.bottomMargin: 80
        anchors.topMargin: -40   // <-- shifts ALL content upward

        spacing: 20


        // =============================================================
        // TOP ROW  →  metric boxes (left)   |   bar meters (right)
        // =============================================================

        // Reusable component for white metric boxes
        Component {
            id: metricBox
            Rectangle {
                width: 150
                height: 30
                radius: 6
                color: root.metricBoxColor === "transparent" ? "transparent" : root.metricBoxColor
                border.color: "#888"

                property string label: ""
                property string unit: ""
                property real value: 0

                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        text: label + ":"
                        color: "black"
                        font.pixelSize: 14
                    }
                    Text {
                        id: valueText
                        text: value + unit
                        color: "black"
                        font.pixelSize: 14
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            spacing: 40

            // =========================================================
            // LEFT: METRIC BOXES (lower + shifted right)
            // =========================================================
            ColumnLayout {
                id: metricColumn
                Layout.preferredWidth: 160
                spacing: 8

                // Use layout margins instead of anchors
                Layout.topMargin: 150
                Layout.leftMargin: 180

                Loader { id: oilTempBox     ; sourceComponent: metricBox ; onLoaded:{ item.label="Oil Temp"    ; item.unit="°C" } }
                Loader { id: batteryBox     ; sourceComponent: metricBox ; onLoaded:{ item.label="Battery V"   ; item.unit="V"  } }
                Loader { id: coolantBox     ; sourceComponent: metricBox ; onLoaded:{ item.label="Coolant"     ; item.unit="°C" } }
                Loader { id: engineLoadBox  ; sourceComponent: metricBox ; onLoaded:{ item.label="Eng Load"    ; item.unit="%"  } }
            }

            // Flexible empty space
            Item { Layout.fillWidth: true }

            // =========================================================
            // RIGHT: BAR METERS (lower + thinner + centered above RPM)
            // =========================================================
            RowLayout {
                id: barRow
                spacing: 16
                Layout.preferredWidth: 260
                Layout.topMargin: 150
                Layout.rightMargin: 100

                Repeater {
                    model: [
                        { label: "Throttle",  signal: "throttleChanged" },
                        { label: "Fuel Cons", signal: "fuelConsumptionChanged" },
                        { label: "Brakes",    signal: "brakesChanged" }
                    ]

                    delegate: Column {
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter

                        // --- Bar meter instance ---
                        Loader {
                            id: dynBar
                            sourceComponent: barClassic

                            onLoaded: {
                                if (item) {
                                    // initialize value and unit
                                    item.value = 0
                                    if (modelData.label === "Throttle" || modelData.label === "Brakes") {
                                        item.unit = "%"                // Throttle / Brakes
                                    } else if (modelData.label === "Fuel Cons") {
                                        item.unit = "\nL/\n100km"         // Fuel consumption
                                    } else {
                                        item.unit = ""                 // default none
                                    }
                                }
                            }

                            // --- Live updates from backend ---
                            Connections {
                                id: dynConn
                                target: carMetrics

                                function onThrottleChanged(val) {
                                    if (modelData.label === "Throttle" && dynBar.item)
                                        dynBar.item.value = val
                                }

                                function onFuelConsumptionChanged(val) {
                                    if (modelData.label === "Fuel Cons" && dynBar.item)
                                        dynBar.item.value = Math.min(val, 35) // clamp for UI
                                }

                                function onBrakesChanged(val) {
                                    if (modelData.label === "Brakes" && dynBar.item)
                                        dynBar.item.value = val
                                }
                            }
                        }

                        // --- Label below each bar ---
                        Label {
                            text: modelData.label
                            color: "white"
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // --- Base component for the actual bar meter ---
                Component {
                    id: barClassic
                    BarMeter {
                        width: 45
                        height: 135
                        barColor: root.barColor
                        backgroundColor: root.barBgColor
                    }
                }
            }



            Component { id: barGraph
                GraphMeter {
                    title: modelData.label
                    unit: "%"
                    scale: 0.35      // scales the base 220x120 graph to fit your bar slot
                }
            }


        }


        // =============================================================
        // BOTTOM ROW →  left fuel | big speed | right rpm
        // =============================================================
        // =============================================================
        // BOTTOM ROW →  left fuel | big speed (with overlays) | right rpm
        // =============================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 80         // increased spacing to separate gauges

            // --- FUEL METER ---
            Loader {
                id: fuelLoader
                Layout.preferredWidth: 220
                sourceComponent: {
                    if (root.fuelDesign === "bar")     return fuelBar
                    if (root.fuelDesign === "graph")   return fuelGraph
                    return fuelCircular
                }
            }

            // --- SPEEDOMETER with overlay indicators ---
            Item {
                id: speedContainer
                width: 300
                height: 300

                Loader {
                    id: speedLoader
                    anchors.centerIn: parent
                    property real speedValue: 0
                    sourceComponent: speedGauge
                    onLoaded: if (item) item.value = speedValue
                }


                // Overlay indicators directly above gauge
                Column {
                    id: centralIndicators
                    width: parent.width
                    height: 90
                    spacing: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: speedLoader.top
                    anchors.bottomMargin: 12
                    z: 10

                    // --- Status lights ---
                    Row {
                        id: indicatorRow
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10

                        Rectangle {
                            id: engineLight
                            width: 26; height: 26; radius: 13
                            color: "black"
                            border.color: "#ffffff"
                            border.width: 2

                            // smooth color transitions
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Behavior on border.color { ColorAnimation { duration: 200 } }

                            Text {
                                id: engineIcon
                                text: "⚙️"
                                anchors.centerIn: parent
                                color: "white"
                                font.pixelSize: 15
                                font.bold: true
                            }

                            // blink when active
                            SequentialAnimation on opacity {
                                id: engineBlink
                                running: false
                                loops: Animation.Infinite
                                PropertyAnimation { to: 0.4; duration: 400; easing.type: Easing.InOutQuad }
                                PropertyAnimation { to: 1.0; duration: 400; easing.type: Easing.InOutQuad }
                            }
                        }

                        Rectangle {
                            id: warningLight
                            width: 26; height: 26; radius: 13
                            color: "black"
                            border.color: "#ffffff"
                            border.width: 2

                            Behavior on color { ColorAnimation { duration: 200 } }
                            Behavior on border.color { ColorAnimation { duration: 200 } }

                            Text {
                                id: warningIcon
                                text: "⚠️"
                                anchors.centerIn: parent
                                color: "white"
                                font.pixelSize: 16
                                font.bold: true
                            }

                            SequentialAnimation on opacity {
                                id: warningBlink
                                running: false
                                loops: Animation.Infinite
                                PropertyAnimation { to: 0.4; duration: 400; easing.type: Easing.InOutQuad }
                                PropertyAnimation { to: 1.0; duration: 400; easing.type: Easing.InOutQuad }
                            }
                        }


                    }

                    // --- Gear and Steering info ---
                    Label {
                        id: gearLabel
                        text: "Gear: N"
                        font.pixelSize: 22
                        font.bold: true
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Label {
                        id: steeringLabel
                        text: "Steer: 0°"
                        font.pixelSize: 16
                        color: "#99ffaa"
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            // --- RPM METER ---
            Loader {
                id: rpmLoader
                Layout.preferredWidth: 220
                property real rpmValue: 0
                sourceComponent: rpmGauge
                onLoaded: if (item) item.value = rpmValue
            }

        }



        // =============================================================
        // COMPONENT DEFINITIONS (dynamic meter templates)
        // =============================================================

        // --- FUEL ---
        Component { id: fuelCircular
            CircularMeter {
                title: "Fuel"
                maxValue: 100
                unit: "%⛽"
                scale: 0.75
                value: fuelLoader.item ? fuelLoader.item.value : 0
                needleColor: root.speedNeedleColor
                backgroundColor: root.speedBgColor
                tickColor: root.speedTickColor
                mode: root.fuelDesign.toLowerCase() === "submarine" ? "submarine" : "normal"
            }
        }

        Component { id: fuelBar
            BarMeter {
                width: 45
                height: 135
                labelText: "Fuel"
                unit: 'L/100KMpH'
                value: fuelLevelBox.item ? fuelLevelBox.item.value : 0
                barColor: root.barColor
                backgroundColor: root.barBgColor
            }
        }

        // --- SPEED ---
        Component { id: speedGauge
            CircularMeter {
                title: "Speed"
                maxValue: 200
                step: 20
                unit: "km/h"
                scale: 1.4
                needleColor: root.speedNeedleColor
                backgroundColor: root.speedBgColor
                tickColor: root.speedTickColor
                mode: root.speedDesign.toLowerCase() === "submarine" ? "submarine" : "normal"
            }
        }

        // --- RPM ---
        Component { id: rpmGauge
            CircularMeter {
                title: "RPM"
                maxValue: 8000
                step: 1000
                unit: "RPM"
                scale: 0.75
                needleColor: root.rpmNeedleColor
                backgroundColor: root.rpmBgColor
                tickColor: root.rpmTickColor
                mode: root.rpmDesign.toLowerCase() === "submarine" ? "submarine" : "normal"
            }
        }


    }



    // --- SIGNAL CONNECTIONS ---
    Connections {
        target: carMetrics

        function onGearChanged(val) {
            gearLabel.text = "Gear: " + val
        }

        function onSteeringAngleChanged(val) {
            steeringLabel.text = "Steer: " + Math.round(val) + "°"
        }


        function onSpeedChanged(val) {
            if (speedLoader.item) speedLoader.item.value = val
            speedLoader.speedValue = val
        }

        function onRpmChanged(val) {
            if (rpmLoader.item) rpmLoader.item.value = val
            rpmLoader.rpmValue = val
        }


        function onOilTempChanged(val) {
            if (oilTempBox.item)
                oilTempBox.item.value = val
        }

        function onBatteryChanged(val) {
            if (batteryBox.item)
                batteryBox.item.value = val
        }

        function onCoolantChanged(val) {
            if (coolantBox.item)
                coolantBox.item.value = val
        }

        function onFuelLevelChanged(val) {
            if (fuelLoader.item)
                fuelLoader.item.value = val
        }

        function onEngineLoadChanged(val) {
            if (engineLoadBox.item)
                engineLoadBox.item.value = val
        }

        // === Engine Light ===
function onEngineWarningChanged(active) {
    if (active) {
        engineLight.color = "yellow"
        engineIcon.color = "black"
        engineBlink.running = true
    } else {
        // faded inactive look (like blink's dim phase)
        engineLight.color = Qt.rgba(0.5, 0.5, 0, 0.3)   // translucent dark yellow/gray tone
        engineIcon.color = Qt.rgba(1, 1, 1, 0.6)        // soft white
        engineBlink.running = false
        engineLight.opacity = 0.4                       // same as blink low phase
    }
}

// === General Warning Light ===
function onGeneralWarningChanged(active) {
    if (active) {
        warningLight.color = "yellow"
        warningIcon.color = "black"
        warningBlink.running = true
    } else {
        warningLight.color = Qt.rgba(0.5, 0.5, 0, 0.3)
        warningIcon.color = Qt.rgba(1, 1, 1, 0.6)
        warningBlink.running = false
        warningLight.opacity = 0.4
    }
}




    }

    // === REACT TO CONFIG CHANGES ===
    Connections {
        target: configBackend
        function onConfigChanged(cfg) {
            speedDesign = cfg["SPEED_DESIGN"]
            rpmDesign   = cfg["RPM_DESIGN"]
            fuelDesign  = cfg["FUEL_DESIGN"]
            console.log("Updated gauge designs:", speedDesign, rpmDesign, fuelDesign)
        }
    }


    MusicWidget {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 12
        z: 999
}





}
