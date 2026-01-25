import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: root

    property string language : "gr"
    property bool isResizing: false
    width: 900; height: 600; visible: true
    minimumWidth: 450; minimumHeight: 300 // Keep it usable
    readonly property real baseWidth: 900
    readonly property real baseHeight: 600

    //title: root.language === 'gr' ? loginManager.UI_STYLING.titie_gr : loginManager.UI_STYLING.titie_eng
    title: (loginManager && loginManager.UI_STYLING) ? (root.language === 'gr' ? loginManager.UI_STYLING.titie_gr : loginManager.UI_STYLING.titie_eng) : 'Loading...' //kapoios na to handlarei ayto plsssss
    color: (loginManager && loginManager.UI_STYLING) ? loginManager.UI_STYLING.window_colour : "#f0f0f0"


    property bool isAuthenticating: false
    property bool isError: false
    property bool loggedIn: false
    property int animationMode: (loginManager && loginManager.UI_STYLING) ? loginManager.UI_STYLING.animation_mode : 1
    property bool isSuccess: false // Add this new property
    property string currentErrorMessage: ""


    MouseArea { id: mainMouse; anchors.fill: parent; hoverEnabled: true }

    Timer {
        id: resizeTimer
        interval: 250 // Wait 150ms after the last move to show UI again
        onTriggered: root.isResizing = false
    }
    onWidthChanged: { root.isResizing = true; resizeTimer.restart() }
    onHeightChanged: { root.isResizing = true; resizeTimer.restart() }

    readonly property real currentScale: {
        let panelW = loginRow.width * (3/7);
        let panelH = loginRow.height;
        let hRatio = panelH / 550;
        let wRatio = panelW / 350;
        let ratio = Math.min(hRatio, wRatio) * 0.9;
        let baseScale = ratio < 1.0 ? ratio : 1.0 + (ratio - 1.0) * 0.5;

        // CLAMP: Never let it go below 0.65.
        // This ensures the text is always legible.
        return Math.max(baseScale, 0.65);
    }

    // Reset error state after a delay
    Timer {
        id: inputResetTimer
        interval: 500
        onTriggered: {
            userField.text = ""
            passField.text = ""
        }
    }

    // Reset Creature Sadness slowly (3000ms)
    Timer {
        id: errTimer
        interval: 3000
        onTriggered: {
            root.isError = false // Creatures return to neutral/smile here
        }
    }

    // --- SCREEN MANAGER ---
    // If loggedIn is true, show the white screen. Otherwise show the login Row.
    Rectangle {
        id: mainContent
        anchors.fill: parent
        color: "white"
        visible: root.loggedIn

        Label {
            anchors.centerIn: parent
            text: "Welcome to the Dashboard"
            color: "black"; font.pixelSize: 32
        }
    }


    // Status Bar (Top Right)
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 15
        spacing: 10
        z: 100
        visible: !root.loggedIn

        Text {
            text: loginManager.hasInternet ? ((loginManager && loginManager.UI_STYLING) ? loginManager.UI_STYLING.internet_connected_emoji :"📶") : ((loginManager && loginManager.UI_STYLING) ? loginManager.UI_STYLING.internet_error_emoji :"⚠️")
            font.pixelSize: 18
            ToolTip.visible: wifiMouse.containsMouse
            ToolTip.text: loginManager.hasInternet ? ((loginManager && loginManager.UI_STYLING) ? (root.language === 'gr' ? loginManager.UI_STYLING.internet_connected_label_gr :   loginManager.UI_STYLING.internet_connected_label_eng):"Connected to Internet") : ((loginManager && loginManager.UI_STYLING) ? (root.language === 'gr' ? loginManager.UI_STYLING.no_internet_connected_label_gr :   loginManager.UI_STYLING.no_internet_connected_label_eng):"No Internet Connection")

            MouseArea { id: wifiMouse; anchors.fill: parent; hoverEnabled: true; onClicked: loginManager.refreshInternetStatus()} // Forces a fresh check
        }
    }


    // --- LOGIN SCREEN ---
    Item {
        id: loginRow
        anchors.fill: parent
        visible: !root.loggedIn

        Item {
            id: totalUIContainer
            anchors.fill: parent
            opacity: root.isResizing ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 200 } }

            // Your existing 4/7 and 3/7 layout lives here
            Row {
                anchors.fill: parent
                // 4/7 AREA (Creatures)
                Rectangle {
                    id: creaturePanel
                    width: root.animationMode === 0 ? 0 : parent.width * (4 / 7)
                    height: parent.height
                    color: (loginManager && loginManager.UI_STYLING) ? loginManager.UI_STYLING.creatures_background_colour : "#2c3e50"
                    clip: true
                    Behavior on width {
                        NumberAnimation {
                            duration: 400; easing.type: Easing.InOutQuad
                        }
                    }

                    CreatureArea {
                        anchors.fill: parent
                        mode: root.animationMode
                        isAuthenticating: root.isSuccess
                        isError: root.isError
                        mouseSource: mainMouse
                        // movementSpeed: 0.5 // Reduce this to stop the "crazy" spinning
                        // collisionElasticity: 0.2 // Low elasticity = "calm" bounces
                    }
                }

                // 3/7 AREA (Login UI)
                Rectangle {
                    id: loginPanel
                    width: root.animationMode === 0 ? parent.width : parent.width * (3 / 7)
                    height: parent.height
                    color: (loginManager && loginManager.UI_STYLING) ? loginManager.UI_STYLING.login_ui_color : "transparent"
                    Behavior on width {
                        NumberAnimation {
                            duration: 400; easing.type: Easing.InOutQuad
                        }
                    }


                    transform: Translate {
                        id: shakeTranslate
                        x: 0
                    }

                    SequentialAnimation {
                        id: shakeAnim
                        // running: root.isError // Triggers whenever isError is set to true
                        loops: 1
                        NumberAnimation {
                            target: shakeTranslate; property: "x";
                            from: 0;
                            to: -10; duration: 50; easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            target: shakeTranslate; property: "x";
                            from: -10;
                            to: 10; duration: 50; easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            target: shakeTranslate; property: "x";
                            from: 10;
                            to: -10; duration: 50; easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            target: shakeTranslate; property: "x";
                            from: -10;
                            to: 10; duration: 50; easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            target: shakeTranslate; property: "x";
                            from: 10;
                            to: 0; duration: 50; easing.type: Easing.InOutQuad
                        }
                    }


                    ColumnLayout {
                        id: realUI
                        anchors.centerIn: parent
                        width: Math.min(parent.width * 0.8, 350)
                        spacing: 15
                        opacity: root.isResizing ? 0 : 1

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 150
                            }
                        }

                        Label {
                            text: (loginManager && loginManager.UI_STYLING) ? (root.language === 'gr' ? loginManager.UI_STYLING.login_ui_label_gr : loginManager.UI_STYLING.login_ui_label_eng) : "System Login"; font.pixelSize: 28; font.bold: true
                            color: (loginManager && loginManager.UI_STYLING) ? loginManager.UI_STYLING.login_label_colour : "#000000"; Layout.alignment: Qt.AlignHCenter
                        }

                        TextField {
                            id:
                                userField; placeholderText: (loginManager && loginManager.UI_STYLING) ? (root.language === 'gr' ? loginManager.UI_STYLING.username_label_gr : loginManager.UI_STYLING.username_label_eng) : "Username"; Layout.fillWidth: true
                            color: (loginManager && loginManager.UI_STYLING) ? loginManager.UI_STYLING.username_text_colour : "#000000"; font.pixelSize: 16; font.bold: true
                            placeholderTextColor: "#666666" // Add this!
                            background: Rectangle {
                                border.color: (loginManager && loginManager.UI_STYLING) ? loginManager.UI_STYLING.username_background_colour : "black"; border.width: 2
                            }
                            onAccepted: passField.forceActiveFocus() // Moves to password
                        }

                        TextField {
                            id:
                                passField; placeholderText: (loginManager && loginManager.UI_STYLING) ? (root.language === 'gr' ? loginManager.UI_STYLING.password_label_gr : loginManager.UI_STYLING.password_label_eng) : "Password"; Layout.fillWidth: true
                            placeholderTextColor: "#666666" // Add this!
                            property bool showPassword: false
                            echoMode: showPassword ? TextInput.Normal : TextInput.Password

                            color: (loginManager && loginManager.UI_STYLING) ? loginManager.UI_STYLING.password_text_colour : "#000000"
                            font.pixelSize: 16
                            background: Rectangle {
                                border.color: (loginManager && loginManager.UI_STYLING) ? loginManager.UI_STYLING.password_background_colour : "black"
                                border.width: 2
                            }
                            // The Eye Icon
                            // THE INVISIBLE EYE
                            Item {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30; height: 30

                                Text {
                                    anchors.centerIn: parent
                                    text: passField.showPassword ? ((loginManager && loginManager.UI_STYLING) ? loginManager.UI_STYLING.password_make_visible_button : "👁️") : ((loginManager && loginManager.UI_STYLING) ? loginManager.UI_STYLING.password_make_invisible_button : "🙈")
                                    font.pixelSize: 18
                                    opacity: 0.7
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: passField.showPassword = !passField.showPassword
                                    // No background, no grey box!
                                }
                            }
                            onAccepted: dbIPField.forceActiveFocus() // Moves to DB IP
                        }

                        TextField {
                            id: dbIPField
                            placeholderText: (loginManager && loginManager.UI_STYLING) ? (root.language === 'gr' ? loginManager.UI_STYLING.db_ip_label_gr : loginManager.UI_STYLING.db_ip_label_eng) : "Database IP:"
                            Layout.fillWidth: true
                            echoMode: TextInput.Normal // Changed from Password to Normal
                            color: (loginManager && loginManager.UI_STYLING) ? loginManager.UI_STYLING.db_ip_text_colour : "#000000"
                            font.pixelSize: 16
                            placeholderTextColor: "#666666"
                            background: Rectangle {
                                border.color: (loginManager && loginManager.UI_STYLING) ? loginManager.UI_STYLING.db_ip_background_colour : "black"; border.width: 2
                            }
                            onAccepted: loginBtn.clicked()
                        }

                        Button {
                            id: loginBtn
                            text: (loginManager && loginManager.UI_STYLING) ? (root.language === 'gr' ? loginManager.UI_STYLING.login_button_label_gr : loginManager.UI_STYLING.login_button_label_eng) : "Login"
                            Layout.fillWidth: true; highlighted: true
                            contentItem: Text {
                                text: (loginManager && loginManager.UI_STYLING) ? (root.language === 'gr' ? loginManager.UI_STYLING.login_button_label_gr : loginManager.UI_STYLING.login_button_label_eng) : "Login"; color: (loginManager && loginManager.UI_STYLING) ? loginManager.UI_STYLING.login_button_text_colour : "white"; font.bold: true; horizontalAlignment: Text.AlignHCenter
                            }
                            background: Rectangle {
                                color: (loginManager && loginManager.UI_STYLING) ? loginManager.UI_STYLING.login_button_background_colour : "#27ae60"; radius: 4
                            }
                            onClicked: {
                                errTimer.stop()
                                root.currentErrorMessage = "" // Clear the old error immediately
                                root.isError = false
                                root.isAuthenticating = true
                                customProg.barState = "parsing" // Start Blue
                                blueAnim.start()
                                loginManager.attempt_login(userField.text, passField.text, dbIPField.text)
                            }
                        }
                        // Offline Warning (Conditional on Internet)
                        Label {
                            visible: !loginManager.hasInternet
                            text: root.language === 'gr' ? "* Δεν υπάρχει σύνδεση στο διαδίκτυο. Δυνατή μόνο η τοπική σύνδεση." : "* Internet Connection isn't available. Connection to local DBs possible only."
                            color: "#d35400"
                            font.pixelSize: 11
                            font.italic: true
                            Layout.alignment: Qt.AlignHCenter
                        }

                        // --- OFFLINE & INFO SECTION ---
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            Button {
                                text: (loginManager && loginManager.UI_STYLING) ? (root.language === 'gr' ? loginManager.UI_STYLING.try_offline_mode_label_gr : loginManager.UI_STYLING.try_offline_mode_label_eng) : "Try Offline Mode"
                                Layout.fillWidth: true
                                onClicked: console.log("Entering Offline Mode...")
                            }
                            Rectangle {
                                width: 24; height: 24; radius: 12; color: (loginManager && loginManager.UI_STYLING) ? loginManager.UI_STYLING.entering_offline_mode_background_colour : "#34495e"
                                Text {
                                    text: "i"; color: (loginManager && loginManager.UI_STYLING) ? loginManager.UI_STYLING.entering_offline_mode_text_colour : "white"; anchors.centerIn: parent; font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    ToolTip.visible: containsMouse
                                    ToolTip.delay: 100
                                    ToolTip.text: (loginManager && loginManager.UI_STYLING) ? (root.language === 'gr' ? loginManager.UI_STYLING.offline_mode_explanation_label_gr : loginManager.UI_STYLING.offline_mode_explanation_label_eng) : "If you have logged in before, your configurations\nare stored locally and ready to be previewed."
                                }
                            }
                        }

                        ProgressBar {
                            id: customProg
                            visible: root.isAuthenticating || root.isError
                            Layout.fillWidth: true

                            // States: "parsing" (blue) or "success" (green)
                            property string barState: "parsing"

                            background: Rectangle {
                                implicitHeight: 6; color: (loginManager && loginManager.UI_STYLING) ? loginManager.UI_STYLING.success_progress_bar_background_colour : "#eee"; radius: 3
                            }

                            contentItem: Item {
                                Rectangle {
                                    width: customProg.visualPosition * parent.width
                                    height: parent.height
                                    radius: 4
                                    // Color changes based on the state
                                    color: customProg.barState === "parsing" ? "#3498db" : "#27ae60"
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 400
                                        }
                                    }
                                }
                            }


                            // Animation 1: The 5-second Blue "Parsing" Bar
                            PropertyAnimation {
                                id: blueAnim
                                target: customProg; property: "value"
                                from: 0;
                                to: 1.0; duration: 5000
                                easing.type: Easing.OutCubic
                            }

                            // Animation 2: The 2-second Green "Success" Bar
                            PropertyAnimation {
                                id: greenAnim
                                target: customProg; property: "value"
                                from: 0;
                                to: 1.0; duration: 2000
                                onFinished: root.loggedIn = true // Success! Switch screens
                            }
                        }

                        Label {
                            // Keep visible if there is a message and we aren't currently "Parsing" or "Successful"
                            visible: currentErrorMessage !== "" && !root.isAuthenticating && !root.isSuccess
                            text: currentErrorMessage
                            color: (loginManager && loginManager.UI_STYLING) ? loginManager.UI_STYLING.login_error_colour : "red"
                            font.bold: true; font.pixelSize: 12
                            Layout.alignment: Qt.AlignHCenter; horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap; Layout.preferredWidth: parent.width
                        }
                    }


                }
            }
        }

        // THE UNIVERSAL RESIZE TEXT (Centered on the whole screen)
        Item {
            anchors.fill: parent
            visible: opacity > 0
            opacity: root.isResizing ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Column {
                anchors.centerIn: parent
                spacing: 10
                Text {
                    text: root.width > root.baseWidth ? "EXPANDING" : "SHRINKING"
                    color: "#bdc3c7"; font.pixelSize: 24; font.bold: true; font.letterSpacing: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    // This text scales in real-time as they drag
                    text: Math.round(root.currentScale * 100) + "%"
                    color: "white"; font.pixelSize: 80 * root.currentScale; font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
    }
    }

    // --- SETTINGS POPUP ---
    Button {
        id: settingsBtn; text: (loginManager && loginManager.UI_STYLING) ? (root.language === 'gr' ? loginManager.UI_STYLING.animation_settings_label_gr :   loginManager.UI_STYLING.animation_settings_label_eng):"⚙ Settings"; z: 100
        anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 15
        onClicked: settingsPopup.open()
        visible: !root.loggedIn
    }
    Button {
        id: langBtn
        text: root.language === "en" ? "Ελληνικά" : "English"
        z: 100
        anchors.top: parent.top
        anchors.left: settingsBtn.right // Position it next to settings
        anchors.leftMargin: 10
        anchors.topMargin: 15
        onClicked: root.language = (root.language === "en" ? "gr" : "en")
    }

    Popup {
        id: settingsPopup
        x: settingsBtn.x; y: settingsBtn.y + settingsBtn.height + 5
        width: 180; background: Rectangle { border.color: (loginManager && loginManager.UI_STYLING) ? loginManager.UI_STYLING.animation_settings_background_colour :"black"; border.width: 2; radius: 5 }
        Column {
            spacing: 2; anchors.fill: parent
            Repeater {
                model: (loginManager && loginManager.UI_STYLING) ? (root.language === 'gr' ? loginManager.UI_STYLING.animation_settings_dropdown_list_gr :   loginManager.UI_STYLING.animation_settings_dropdown_list_eng):["No Creatures", "1 Creature", "Many Creatures"]
                delegate: Button {
                    width: parent.width; flat: true
                    contentItem: Text { text: modelData; color: "#000000"; font.bold: true }
                    onClicked: { root.animationMode = index; settingsPopup.close() }
                }
            }
        }
    }

    // --- PYTHON CONNECTIONS ---
    Connections {
        target: loginManager

        function onLoginSuccess() {
            // Stop the blue bar immediately
            blueAnim.stop()
            root.isSuccess = true // Trigger the smiles now!
            // Switch to success mode
            customProg.barState = "success"
            customProg.value = 0 // Reset to fill up green
            greenAnim.start()

            // Creatures will now smile because root.isAuthenticating is true
            // and isError is false!
        }

        function onLoginFailed(error_reason) {
            blueAnim.stop()
            root.isAuthenticating = false
            root.isError = true

            // Base message from UI_STYLING
            let baseMsg = (loginManager && loginManager.UI_STYLING) ?
                (root.language === 'gr' ? loginManager.UI_STYLING.login_error_message_gr : loginManager.UI_STYLING.login_error_message_eng) :
                "Login Failed"

            // Concatenate if error_reason is not empty
            if (error_reason && error_reason !== "") {
                root.currentErrorMessage = baseMsg + "\n(" + error_reason + ")"
            } else {
                root.currentErrorMessage = baseMsg
            }

            customProg.value = 0
            shakeAnim.start()
            inputResetTimer.start()
            errTimer.start()
        }
    }

    Component.onCompleted: userField.forceActiveFocus()
}