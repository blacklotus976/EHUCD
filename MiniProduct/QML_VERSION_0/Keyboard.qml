import QtQuick 6.9
import QtQuick.Controls.Basic

Popup {
    id: keyboard
    width: parent ? parent.width : 1280
    height: parent ? parent.height * 0.6 : 400
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    y: parent ? parent.height - height : 0
    z: 99999

    property bool shift: false
    property bool symbols: false
    property var targetField: null
    signal collapsed()

    background: Rectangle {
        anchors.fill: parent
        color: "#0a0a0a"
        border.color: "#00ff80"
        border.width: 2
        radius: 12
    }

    function sendKey(txt) {
        if (targetField && targetField.text !== undefined) {
            let pos = targetField.cursorPosition
            targetField.insert(pos, txt)     // ✅ correct usage
            targetField.cursorPosition = pos + txt.length
        }
    }

    function backspace() {
        if (targetField && targetField.cursorPosition > 0) {
            let pos = targetField.cursorPosition
            targetField.remove(pos - 1, pos)
            targetField.cursorPosition = pos - 1
        }
    }


    function hide() {
        keyboard.visible = false
        keyboard.collapsed()
    }

    // block clicks behind keyboard
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.4)
        MouseArea { anchors.fill: parent }
    }

    // === main layout ===
    Column {
        anchors.centerIn: parent
        spacing: 10

        // === rows of keys ===
        Column {
            id: keyRows
            spacing: 8
            Repeater {
                model: symbols ? [
                    ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "_"],
                    ["+", "=", "{", "}", "[", "]", "|", "\\", ":", ";"],
                    ["'", "\"", ",", ".", "/", "?", "<", ">", "~"]
                ] : [
                    ["1","2","3","4","5","6","7","8","9","0"],
                    ["q","w","e","r","t","y","u","i","o","p"],
                    ["a","s","d","f","g","h","j","k","l"],
                    ["z","x","c","v","b","n","m"]
                ]

                delegate: Row {
                    spacing: 6
                    anchors.horizontalCenter: parent.horizontalCenter

                    Repeater {
                        model: modelData
                        delegate: Rectangle {
                            width: 70; height: 60; radius: 8
                            color: "#002000"
                            border.color: "#00ff80"
                            Text {
                                anchors.centerIn: parent
                                text: keyboard.shift ? modelData.toUpperCase() : modelData
                                color: "#aaffaa"
                                font.pixelSize: 22
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: keyboard.sendKey(keyboard.shift ? modelData.toUpperCase() : modelData)
                            }
                        }
                    }
                }
            }
        }

        // === control row ===
        Row {
            spacing: 10
            anchors.horizontalCenter: parent.horizontalCenter
            height: 70

            Rectangle {
                width: 100; height: 60; radius: 8
                color: keyboard.shift ? "#004400" : "#002200"
                border.color: "#00ff80"
                Text { anchors.centerIn: parent; text: "⇧"; color: "#00ffcc"; font.pixelSize: 22 }
                MouseArea { anchors.fill: parent; onClicked: keyboard.shift = !keyboard.shift }
            }

            Rectangle {
                width: 90; height: 60; radius: 8
                color: keyboard.symbols ? "#004400" : "#002200"
                border.color: "#00ff80"
                Text { anchors.centerIn: parent; text: keyboard.symbols ? "ABC" : "@#?"; color: "#00ffaa"; font.pixelSize: 20 }
                MouseArea { anchors.fill: parent; onClicked: keyboard.symbols = !keyboard.symbols }
            }

            Rectangle {
                width: 300; height: 60; radius: 8
                color: "#001800"
                border.color: "#00ff80"
                Text { anchors.centerIn: parent; text: "Space"; color: "#00ffaa"; font.pixelSize: 20 }
                MouseArea { anchors.fill: parent; onClicked: keyboard.sendKey(" ") }
            }

            Rectangle {
                width: 80; height: 60; radius: 8
                color: "#002200"
                border.color: "#00ff80"
                Text { anchors.centerIn: parent; text: "⏎"; color: "#00ffaa"; font.pixelSize: 20 }
                MouseArea { anchors.fill: parent; onClicked: keyboard.sendKey("\n") }
            }

            Rectangle {
                width: 80; height: 60; radius: 8
                color: "#330000"
                border.color: "#ff6666"
                Text { anchors.centerIn: parent; text: "⌫"; color: "#ffaaaa"; font.pixelSize: 20 }
                MouseArea { anchors.fill: parent; onClicked: keyboard.backspace() }
            }

            Rectangle {
                width: 80; height: 60; radius: 8
                color: "#002200"
                border.color: "#00ff80"
                Text { anchors.centerIn: parent; text: "▼"; color: "#00ff80"; font.pixelSize: 20 }
                MouseArea { anchors.fill: parent; onClicked: keyboard.hide() }
            }
        }
    }
}
