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
        speedDesign = d[0]
        rpmDesign = d[1]
        fuelDesign = d[2]
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
            if (typeof navigator !== "undefined" && typeof navigator.changeScreen === "function") {
                navigator.changeScreen("music")
                // console.log("Switching to music screen")
            } else {
                console.warn("Navigator not found")
            }
        }
    }



    // --- MAPS BUTTON ---
    Button {
        id: mapsBtn
        text: "MAPS"
        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.left: musicScreenBtn.right
        anchors.leftMargin: 10
        width: 80
        height: 32
        onClicked: {
            if (root && typeof root.changeScreen === "function") {
                root.changeScreen("music")
                console.log("Switching to music screen")
            }
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

                // Use layout margins, not anchors
                Layout.topMargin: 150
                Layout.rightMargin: 100

                Repeater {
                    model: [
                        { label: "Throttle",  signal: "throttleChanged" },
                        { label: "Brakes",    signal: "brakesChanged" }
                    ]

                    delegate: Column {
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter

                        Loader {
                            id: dynBar

                            sourceComponent: {
                                if (modelData.label === "Throttle")
                                    return root.throttleDesign === "graph" ? barGraph : barClassic
                                if (modelData.label === "Brakes")
                                    return root.brakeDesign === "graph" ? barGraph : barClassic
                                return barClassic
                            }

                            onLoaded: if (item) item.value = 0

                            Connections {
                                target: carMetrics
                                function onThrottleChanged(val) {
                                    if (modelData.label === "Throttle" && dynBar.item)
                                        dynBar.item.value = val
                                }
                                function onBrakesChanged(val) {
                                    if (modelData.label === "Brakes" && dynBar.item)
                                        dynBar.item.value = val
                                }
                            }
                        }


                        Label {
                            text: modelData.label
                            color: "white"
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
            Component { id: barClassic
                BarMeter {
                    width: 45
                    height: 135
                    barColor: root.barColor
                    backgroundColor: root.barBgColor
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
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 40

            // FUEL METER (dynamic)
            Loader {
                id: fuelLoader
                sourceComponent: {
                    if (root.fuelDesign === "bar")     return fuelBar
                    if (root.fuelDesign === "graph")   return fuelGraph
                    return fuelCircular
                }
            }

            // SPEEDOMETER (dynamic)
            Loader {
                id: speedLoader
                property real speedValue: 0
                sourceComponent: {
                    if (root.speedDesign === "circular") return speedCircular
                    if (root.speedDesign === "flower" || root.speedDesign === "submarine") return speedFlower
                    if (root.speedDesign === "graph") return speedGraph
                    return speedCircular
                }
                onLoaded: if (item) item.value = speedValue
            }

            // RPM (dynamic)
            Loader {
                id: rpmLoader
                property real rpmValue: 0
                sourceComponent: {
                    if (root.rpmDesign === "circular") return rpmCircular
                    if (root.rpmDesign === "flower" || root.rpmDesign === "submarine") return rpmFlower
                    if (root.rpmDesign === "graph") return rpmGraph
                    return rpmCircular
                }
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
            }
        }

        Component { id: fuelBar
            BarMeter {
                width: 45
                height: 135
                labelText: "Fuel"
                value: fuelLevelBox.item ? fuelLevelBox.item.value : 0
                barColor: root.barColor
                backgroundColor: root.barBgColor
            }
        }

        // --- SPEED ---
        Component { id: speedCircular
            CircularMeter {
                title: "Speed"
                maxValue: 200
                step: 20
                unit: "km/h"
                scale: 1.4
                needleColor: root.speedNeedleColor
                backgroundColor: root.speedBgColor
                tickColor: root.speedTickColor
                flowerLike: false
            }
        }

        Component { id: speedFlower
            CircularMeter {
                title: "Speed"
                maxValue: 200
                step: 20
                unit: "km/h"
                scale: 1.4
                needleColor: root.speedNeedleColor
                backgroundColor: root.speedBgColor
                tickColor: root.speedTickColor
                flowerLike: true
            }
        }

        Component { id: speedGraph
            GraphMeter {
                title: "Speed"
                maxValue: 200
                unit: "km/h"
            }
        }

        Component { id: fuelGraph
            GraphMeter {
                title: "Fuel"
                unit: "%"
                scale: 0.35
            }
        }


        // --- RPM ---
        Component { id: rpmCircular
            CircularMeter {
                title: "RPM"
                maxValue: 8000
                step: 1000
                unit: "RPM"
                scale: 0.75
                needleColor: root.rpmNeedleColor
                backgroundColor: root.rpmBgColor
                tickColor: root.rpmTickColor
                flowerLike: false
            }
        }

        Component { id: rpmFlower
            CircularMeter {
                title: "RPM"
                maxValue: 8000
                step: 1000
                unit: "RPM"
                scale: 0.75
                needleColor: root.rpmNeedleColor
                backgroundColor: root.rpmBgColor
                tickColor: root.rpmTickColor
                flowerLike: true
            }
        }

        Component { id: rpmGraph
            GraphMeter {
                title: "RPM"
                maxValue: 8000
                unit: "RPM"
            }
        }

    }



    // --- SIGNAL CONNECTIONS ---
    Connections {
        target: carMetrics

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

    }

    MusicWidget {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 12
        z: 999
}





}
