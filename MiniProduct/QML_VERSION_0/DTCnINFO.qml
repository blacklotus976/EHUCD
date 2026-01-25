import QtQuick 6.9
import QtQuick.Controls 6.9
import "core" // for GraphMeter.qml

Item {
    id: root
    width: 1280
    height: 720

    property var navigator
    property var carMetrics

    Rectangle { anchors.fill: parent; color: "#101010" }

    // === Top bar ===
    Rectangle {
        id: topBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        color: "#1e1e1e"

        Row {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 20

            Button {
                text: "← Back"
                onClicked: {
                    if (navigator && typeof navigator.changeScreen === "function")
                        navigator.changeScreen("main")
                    else
                        console.warn("Navigator not found for DTCInfo")
                }
            }

            Label {
                text: "Diagnostics, Logs & Stats"
                anchors.verticalCenter: parent.verticalCenter
                color: "white"
                font.bold: true
                font.pixelSize: 20
            }
        }
    }

    // === MAIN BODY ===
    Column {
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        spacing: 10

        // === TOP SECTION ===
        Row {
            width: parent.width
            height: parent.height * 0.66
            spacing: 10

            // === DTC CODES ===
            Rectangle {
                id: dtcPanel
                width: parent.width / 2 - 5
                height: parent.height
                color: "#181818"
                radius: 8
                border.color: "#333"

                property int pageSize: 10
                property int currentPage: 1
                property var dtcData: []
                property int totalItems: dtcData.length
                property int totalPages: Math.max(1, Math.ceil(totalItems / pageSize))

                function pagedItems() {
                    const start = (currentPage - 1) * pageSize
                    return dtcData.slice(start, start + pageSize)
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    Label {
                        text: "DTC Codes"
                        color: "white"
                        font.bold: true
                        font.pixelSize: 16
                    }

                    // Empty message
                    Text {
                        visible: dtcPanel.dtcData.length === 0
                        text: "No diagnostic trouble codes found."
                        color: "#888"
                        font.pixelSize: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Repeater {
                        visible: dtcPanel.dtcData.length > 0
                        model: dtcPanel.pagedItems()
                        delegate: Rectangle {
                            width: parent.width
                            height: 28
                            color: index % 2 === 0 ? "#202020" : "#2a2a2a"

                            Item {
                                id: dtcTextContainer
                                width: parent.width
                                height: parent.height
                                clip: true

                                property real scrollSpeed: 35        // px/sec
                                property real pauseTime: 1500
                                property bool active: true

                                Text {
                                    id: dtcScrollText
                                    text: modelData
                                    color: "#ffd700"
                                    font.pixelSize: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                    horizontalAlignment: Text.AlignLeft
                                    elide: Text.ElideNone
                                    wrapMode: Text.NoWrap
                                    x: 0

                                    onContentWidthChanged: dtcScrollAnim.restart()
                                    onTextChanged: dtcScrollAnim.restart()
                                }

                                SequentialAnimation {
                                    id: dtcScrollAnim
                                    running: dtcTextContainer.active
                                    loops: Animation.Infinite
                                    PropertyAnimation {
                                        target: dtcScrollText
                                        property: "x"
                                        to: dtcScrollText.contentWidth > dtcTextContainer.width ?
                                            -(dtcScrollText.contentWidth - dtcTextContainer.width + 10) : 0
                                        duration: dtcScrollText.contentWidth > dtcTextContainer.width ?
                                            (dtcScrollText.contentWidth / dtcTextContainer.scrollSpeed) * 1000 : 4000
                                        easing.type: Easing.Linear
                                    }
                                    PauseAnimation { duration: dtcTextContainer.pauseTime }
                                    ScriptAction { script: dtcScrollText.x = 0 }
                                    PauseAnimation { duration: dtcTextContainer.pauseTime }
                                }
                            }
                        }

                    }

                    Row {
                        visible: dtcPanel.totalPages > 1
                        width: parent.width
                        height: 40
                        spacing: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        Button {
                            text: "▲ Prev"
                            enabled: dtcPanel.currentPage > 1
                            onClicked: dtcPanel.currentPage--
                        }
                        Label {
                            text: "Page " + dtcPanel.currentPage + " / " + dtcPanel.totalPages
                            color: "white"
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Button {
                            text: "▼ Next"
                            enabled: dtcPanel.currentPage < dtcPanel.totalPages
                            onClicked: dtcPanel.currentPage++
                        }
                    }
                }
            }

            // === SYSTEM LOGS ===
            Rectangle {
                id: logPanel
                width: parent.width / 2 - 5
                height: parent.height
                color: "#181818"
                radius: 8
                border.color: "#333"

                property int pageSize: 10
                property int currentPage: 1
                property var logData: []
                property int totalItems: logData.length
                property int totalPages: Math.max(1, Math.ceil(totalItems / pageSize))

                function pagedItems() {
                    const start = (currentPage - 1) * pageSize
                    return logData.slice(start, start + pageSize)
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    Label {
                        text: "System Logs"
                        color: "white"
                        font.bold: true
                        font.pixelSize: 16
                    }

                    Repeater {
                        id: logRepeater
                        model: logPanel.pagedItems()
                        delegate: Rectangle {
                            width: parent.width
                            height: 24
                            color: index % 2 === 0 ? "#202020" : "#2a2a2a"

                            Item {
                                id: logTextContainer
                                width: parent.width
                                height: parent.height
                                clip: true

                                property real scrollSpeed: 35
                                property real pauseTime: 1500
                                property bool active: true

                                Text {
                                    id: logScrollText
                                    text: modelData
                                    color: "#a0ffa0"
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    horizontalAlignment: Text.AlignLeft
                                    elide: Text.ElideNone
                                    wrapMode: Text.NoWrap
                                    x: 0

                                    onContentWidthChanged: logScrollAnim.restart()
                                    onTextChanged: logScrollAnim.restart()
                                }

                                SequentialAnimation {
                                    id: logScrollAnim
                                    running: logTextContainer.active
                                    loops: Animation.Infinite
                                    PropertyAnimation {
                                        target: logScrollText
                                        property: "x"
                                        to: logScrollText.contentWidth > logTextContainer.width ?
                                            -(logScrollText.contentWidth - logTextContainer.width + 10) : 0
                                        duration: logScrollText.contentWidth > logTextContainer.width ?
                                            (logScrollText.contentWidth / logTextContainer.scrollSpeed) * 1000 : 4000
                                        easing.type: Easing.Linear
                                    }
                                    PauseAnimation { duration: logTextContainer.pauseTime }
                                    ScriptAction { script: logScrollText.x = 0 }
                                    PauseAnimation { duration: logTextContainer.pauseTime }
                                }
                            }
                        }

                    }

                    Row {
                        width: parent.width
                        height: 40
                        spacing: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        Button {
                            text: "▲ Prev"
                            enabled: logPanel.currentPage > 1
                            onClicked: logPanel.currentPage--
                        }
                        Label {
                            text: "Page " + logPanel.currentPage + " / " + logPanel.totalPages
                            color: "white"
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Button {
                            text: "▼ Next"
                            enabled: logPanel.currentPage < logPanel.totalPages
                            onClicked: logPanel.currentPage++
                        }
                    }
                }
            }
        }

        // === BOTTOM SECTION (graphs) ===
        Row {
            width: parent.width
            height: parent.height * 0.33
            spacing: 10

            // --- Average Speed ---
            Rectangle {
                width: parent.width / 2 - 5
                height: parent.height
                color: "#181818"
                radius: 8
                border.color: "#333"

                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    Label {
                        text: "Average Speed (km/h)"
                        color: "white"
                        font.bold: true
                        font.pixelSize: 16
                    }
                    GraphMeter {
                        id: speedGraph
                        title: "Average Speed"
                        unit: "km/h"
                        maxValue: 160
                        lineColor: "#00ff66"
                        fillColor: "#004422"
                        textColor: "white"
                    }
                }
            }

            // --- Average Fuel Level ---
            Rectangle {
                width: parent.width / 2 - 5
                height: parent.height
                color: "#181818"
                radius: 8
                border.color: "#333"

                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    Label {
                        text: "Average Fuel Level (%)"
                        color: "white"
                        font.bold: true
                        font.pixelSize: 16
                    }
                    GraphMeter {
                        id: fuelGraph
                        title: "Average Fuel Consumption"
                        unit: "L/100km"
                        maxValue: 20
                        lineColor: "#ffaa00"
                        fillColor: "#443300"
                        textColor: "white"
                    }
                }
            }
        }
    }

    // === CONNECTIONS ===
    Connections {
        target: carMetrics

        // Diagnostic codes
        function onDtcCodesChanged(list) {
            dtcPanel.dtcData = list || []
            dtcPanel.currentPage = 1
        }

        // Mini logger
        function onMiniLoggerChanged(lines) {
            if (!lines || lines.length === 0)
                return

            // Append new lines only if newer than existing ones
            let current = logPanel.logData
            let newLines = []

            for (let i = 0; i < lines.length; i++) {
                if (current.indexOf(lines[i]) === -1)
                    newLines.push(lines[i])
            }

            if (newLines.length > 0)
                logPanel.logData = current.concat(newLines)

            // Don't change currentPage automatically
            logPanel.totalItems = logPanel.logData.length
            logPanel.totalPages = Math.max(1, Math.ceil(logPanel.totalItems / logPanel.pageSize))
        }


        // Live graphs
        function onSpeedSeriesChanged(points) {
            if (points && points.length > 0)
                speedGraph.value = points[points.length - 1]
        }
        function onFuelSeriesChanged(points) {
            if (points && points.length > 0)
                fuelGraph.value = points[points.length - 1]
        }
    }
}
