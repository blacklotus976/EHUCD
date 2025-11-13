import QtQuick 6.9
import QtQuick.Controls 6.9
import QtQuick.Layouts 6.9
import QtQuick.Controls.Material

Dialog {
        id: colorSettingsDialog
        property var colorOptionsHere: []
        property color speedNeedleColor
        property color speedBgColor
        property color speedTickColor
        property color rpmNeedleColor
        property color rpmBgColor
        property color rpmTickColor
        property color barColor
        property color barBgColor
        property color metricBoxColor

        title: "Customize Colors"
        modal: true
        Material.theme: Material.Dark
        Material.background: "#2b2b2b"
        standardButtons: Dialog.Ok | Dialog.Cancel
        // palette: root.palette
        background: Rectangle {
        color: Material.background  // consistent Material grey
        radius: 10
        border.color: "#404040"
    }

        onAccepted: {
            root.speedNeedleColor = getColorValue(speedNeedleComboBox.currentText);
            root.speedBgColor = getColorValue(speedBgColorComboBox.currentText);
            root.speedTickColor = getColorValue(speedTickColorComboBox.currentText);
            root.rpmNeedleColor = getColorValue(rpmNeedleComboBox.currentText);
            root.rpmBgColor = getColorValue(rpmBgColorComboBox.currentText);
            root.rpmTickColor = getColorValue(rpmTickColorComboBox.currentText);
            root.barColor = getColorValue(barFillColorComboBox.currentText);
            root.barBgColor = getColorValue(barBgColorComboBox.currentText);
            root.metricBoxColor = getColorValue(metricBoxColorComboBox.currentText);
            carMetrics.write_color_settings([
                root.speedNeedleColor,
                root.speedBgColor,
                root.speedTickColor,
                root.rpmNeedleColor,
                root.rpmBgColor,
                root.rpmTickColor,
                root.barBgColor,
                root.barColor,
                root.metricBoxColor
            ])
        }


        // Initialize the dialog using the current colors
        Component.onCompleted: {
            speedNeedleComboBox.currentIndex = colorOptionsHere.findIndex(elem => elem.value === root.speedNeedleColor);
            speedBgColorComboBox.currentIndex = colorOptionsHere.findIndex(elem => elem.value === root.speedBgColor);
            speedTickColorComboBox.currentIndex = colorOptionsHere.findIndex(elem => elem.value === root.speedTickColor);
            rpmNeedleComboBox.currentIndex = colorOptionsHere.findIndex(elem => elem.value === root.rpmNeedleColor);
            rpmBgColorComboBox.currentIndex = colorOptionsHere.findIndex(elem => elem.value === root.rpmBgColor);
            rpmTickColorComboBox.currentIndex = colorOptionsHere.findIndex(elem => elem.value === root.rpmTickColor);
            barFillColorComboBox.currentIndex = colorOptionsHere.findIndex(elem => elem.value === root.barColor);
            barBgColorComboBox.currentIndex = colorOptionsHere.findIndex(elem => elem.value === root.barBgColor);
            metricBoxColorComboBox.currentIndex = colorOptionsHere.findIndex(elem => elem.value === root.metricBoxColor);
        }

        contentItem: Column {
            spacing: 8
            padding: 12

            // ---- SPEEDOMETER ----
            Label { text: "Speedometer Colors"; font.bold: true; color: "#FFFFFF" }

            Row {
                spacing: 8
                // Needle Color
                Column {
                    Label { text: "Needle Color"; color: "#FFFFFF" }
                    ComboBox {
                        id: speedNeedleComboBox
                        model: colorOptionsHere
                        textRole: "name"
                    }
                }
                // Background Color
                Column {
                    Label { text: "Background Color"; color: "#FFFFFF" }
                    ComboBox {
                        id: speedBgColorComboBox
                        model: colorOptionsHere
                        textRole: "name"
                    }
                }
                // Ticks Color
                Column {
                    Label { text: "Ticks Color"; color: "#FFFFFF" }
                    ComboBox {
                        id: speedTickColorComboBox
                        model: colorOptionsHere
                        textRole: "name"
                    }
                }
            }

            // ---- RPM ----
            Label { text: "RPM Colors"; font.bold: true; color: "#FFFFFF" }
            Row {
                spacing: 8
                // Needle Color
                Column {
                    Label { text: "Needle Color"; color: "#FFFFFF" }
                    ComboBox {
                        id: rpmNeedleComboBox
                        model: colorOptionsHere
                        textRole: "name"
                    }
                }
                // Background Color
                Column {
                    Label { text: "Background Color"; color: "#FFFFFF" }
                    ComboBox {
                        id: rpmBgColorComboBox
                        model: colorOptionsHere
                        textRole: "name"
                    }
                }
                // Ticks Color
                Column {
                    Label { text: "Ticks Color"; color: "#FFFFFF" }
                    ComboBox {
                        id: rpmTickColorComboBox
                        model: colorOptionsHere
                        textRole: "name"
                    }
                }
            }
                    // ---- BARS ----
            Label { text: "Bar Meters"; font.bold: true; color: "#FFFFFF" }
            Row {
                spacing: 8
                // Bar Fill Color
                Column {
                    Label { text: "Bar Fill Color"; color: "#FFFFFF" }
                    ComboBox {
                        id: barFillColorComboBox
                        model: colorOptionsHere
                        textRole: "name"
                        currentIndex: colorOptionsHere.findIndex(elem => elem.value === root.barColor)
                    }
                }
                // Bar Background Color
                Column {
                    Label { text: "Bar Background Color"; color: "#FFFFFF" }
                    ComboBox {
                        id: barBgColorComboBox
                        model: colorOptionsHere
                        textRole: "name"
                        currentIndex: colorOptionsHere.findIndex(elem => elem.value === root.barBgColor)
                    }
                }
            }

            // ---- METRIC BOX ----
            Label { text: "Metric Boxes"; font.bold: true; color: "#FFFFFF" }
            Row {
                spacing: 8
                // Background Color
                Column {
                    Label { text: "Background Color"; color: "#FFFFFF" }
                    ComboBox {
                        id: metricBoxColorComboBox
                        model: colorOptionsHere
                        textRole: "name"
                        currentIndex: colorOptionsHere.findIndex(elem => elem.value === root.metricBoxColor)
                    }
                }
            }
        }
    }