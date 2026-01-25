import QtQuick 6.9
import QtQuick.Controls.Basic
import QtMultimedia 6.9
import "."


Rectangle {
    id: root
    width: 1280
    height: 720
    color: "#080808"

     Component {
        id: scrollingText
        Item {
            id: textContainer
            property string text: ""
            property color color: "white"
            property int pixelSize: 20
            property real scrollSpeed: 40     // lower = slower scroll
            property int pauseTime: 1500




            width: parent ? parent.width : 200
            height: textItem.height
            clip: true

            Text {
                id: textItem
                text: textContainer.text
                color: textContainer.color
                font.pixelSize: textContainer.pixelSize
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
                x: 0
                elide: Text.ElideNone
                wrapMode: Text.NoWrap

                onContentWidthChanged: scrollAnim.restart()
                onTextChanged: scrollAnim.restart()
            }

            SequentialAnimation {
                id: scrollAnim
                running: true
                loops: Animation.Infinite

                PropertyAnimation {
                    target: textItem
                    property: "x"
                    to: textItem.contentWidth > textContainer.width
                        ? -(textItem.contentWidth - textContainer.width + 10)
                        : 0
                    duration: textItem.contentWidth > textContainer.width
                        ? (textItem.contentWidth / textContainer.scrollSpeed) * 1000
                        : 4000
                    easing.type: Easing.Linear
                }
                PauseAnimation { duration: textContainer.pauseTime }
                ScriptAction { script: textItem.x = 0 }
                PauseAnimation { duration: textContainer.pauseTime }
            }
        }
    }



    // --- External connections ---
    property var navigator
    property var musicBackend
    property var configBackend
    property var musicModel: []

    property real localVolume: 100   // 0–100, not system volume
    property bool settingsVisible: false

    property string musicInput: (configBackend ? configBackend.get("MUSIC_PROGRAMM") : "MP3USB")






    // --- Link to MusicCore context property dynamically ---
    property var media:         (MusicCore ? MusicCore.media         : null)
    property var currentFolder: (MusicCore ? MusicCore.currentFolder : null)
    property var currentSong:   (MusicCore ? MusicCore.currentSong   : null)
    property var currentArtist: (MusicCore ? MusicCore.currentArtist : "")
    property var displayTitle:  (MusicCore ? MusicCore.displayTitle  : "")
    property var repeatMode:    (MusicCore ? MusicCore.repeatMode    : "one")


    property string groupMode: "album"

    // --- Configurable parsing ---
    property string musicSeparator
    property int artistIndex
    property int titleIndex
    property int albumIndex

    function toggleGrouping() {
        groupMode = groupMode === "album" ? "artist" : "album"
        reloadMusicModel()
    }


    function updateTitleAndArtist() {
        if (!MusicCore || !MusicCore.media) return;
            MusicCore.updateTitleAndArtist()
    }
    function findSongIndex() {
        if (!MusicCore || !MusicCore.media) return;
            MusicCore.findSongIndex()
    }
    function handleSongEnd() {
        if (!MusicCore || !MusicCore.media) return;
            MusicCore.handleSongEnd()
    }
    function playNextSong() {
        if (!MusicCore || !MusicCore.media) return;
            MusicCore.playNextSong()
    }
    function playPrevSong() {
        if (!MusicCore || !MusicCore.media) return;
            MusicCore.playPrevSong()
    }







    Component.onCompleted: {
        console.log("configBackend available?", !!configBackend, typeof configBackend)
        console.log("🎧 MusicCore bound via context property")

        if (configBackend && typeof configBackend.get === "function") {
            // Fetch each key directly
            const sep = configBackend.get("MUSIC_SEPARATOR")
            const art = configBackend.get("MUSIC_ARTIST_POS")
            const tit = configBackend.get("MUSIC_TITLE_POS")
            const alb = configBackend.get("MUSIC_ALBUM_POS")

            // Apply to properties (with fallbacks if missing)
            if (sep) root.musicSeparator = sep
            if (art) root.artistIndex = parseInt(art)
            if (tit) root.titleIndex = parseInt(tit)
            if (alb) root.albumIndex = parseInt(alb)

            console.log(`🔧 Initial parser config → sep='${musicSeparator}', title=${titleIndex}, artist=${artistIndex}, album=${albumIndex}`)
        } else {
            console.warn("⚠️ configBackend.get() not available in QML context!")
        }
        Qt.callLater(() => {
            if (inputView.item && typeof inputView.item.reloadMusicModel === "function")
                inputView.item.reloadMusicModel()
        })
    }






    // --- Background ---
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#001a00" }
            GradientStop { position: 1; color: "#000000" }
        }
    }
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.25)
    }

    // --- TOP BAR (always visible) ---
    Rectangle {
        id: topBar
        width: parent.width
        height: 60
        anchors.top: parent.top
        color: Qt.rgba(0, 0, 0, 0.45)
        border.color: "#00ff80"
        border.width: 1
        z: 10

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 20
            spacing: 20

            Button {
                text: "🏠 Home"
                width: 120; height: 40
                background: Rectangle {
                    color: "transparent"
                    border.color: "#00ff80"
                    radius: 10
                    border.width: 2
                }
                contentItem: Text {
                    text: parent.text
                    color: "#00ff80"
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (navigator && typeof navigator.changeScreen === "function")
                        navigator.changeScreen("main")
                }
            }

            Text {
                text: "🎶 Music Player"
                color: "#00ffcc"
                font.pixelSize: 24
                font.bold: true
                verticalAlignment: Text.AlignVCenter
            }

            Button {
                id: groupToggle
                visible: root.musicInput === "MP3USB"
                text: root.groupMode === "album" ? "🎨 Group by Artist" : "💿 Group by Album"
                width: 180; height: 40
                background: Rectangle {
                    color: "transparent"
                    border.color: "#00ff80"
                    radius: 10
                    border.width: 2
                }
                contentItem: Text {
                    text: parent.text
                    color: "#00ff80"
                    font.pixelSize: 14
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                // 🔽 Change this line
                onClicked: {
                    if (inputView.item && typeof inputView.item.toggleGrouping === "function")
                        inputView.item.toggleGrouping()
                }

            }


            Button {
                id: settingsBtn
                text: "⚙️"
                width: 42; height: 42
                background: Rectangle {
                    color: "#001800"
                    border.color: "#00ff80"
                    radius: 10
                    border.width: 2
                }
                contentItem: Text {
                    text: parent.text
                    color: "#00ff80"
                    font.pixelSize: 22
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: settingsPopup.open()
            }
        }
    }


    // === MP3 USB VIEW ===
    Component {
        id: mp3UsbView
        Mp3usb { }   // this will load mp3UsbView.qml automatically
    }

    // --- Subtle shadow (optional) ---
    Rectangle {
        anchors.top: topBar.bottom
        width: parent.width
        height: 4
        gradient: Gradient {
            GradientStop { position: 0; color: "#002000aa" }
            GradientStop { position: 1; color: "transparent" }
        }
        z: 9
    }

    // --- Dynamic content loader (starts right below top bar) ---
    Loader {
        id: inputView
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        z: 1
        active: true
        sourceComponent: root.musicInput === "MP3USB"
            ? mp3UsbView
            : (root.musicInput === "RADIO"
                ? radioView
                : (root.musicInput === "BLUETOOTH"
                    ? bluetoothView
                    : mp3UsbView))

        onLoaded: {
            if (item) {
                item.musicBackend  = root.musicBackend
                item.configBackend = root.configBackend
                item.musicModel    = root.musicModel
                item.groupMode     = root.groupMode

                // 🔁 PASS AS BINDINGS so later changes propagate automatically
                item.musicSeparator = Qt.binding(() => root.musicSeparator)
                item.titleIndex     = Qt.binding(() => parseInt(root.titleIndex))
                item.artistIndex    = Qt.binding(() => parseInt(root.artistIndex))
                item.albumIndex     = Qt.binding(() => parseInt(root.albumIndex))

                // kick once (properties will auto-retrigger as bindings update)
                Qt.callLater(() => {
                    if (typeof item.reloadMusicModel === "function")
                        item.reloadMusicModel()
                })
            }
        }

    }



    // === RADIO VIEW ===
    Component {
        id: radioView
        Rectangle {
            anchors.fill: parent
            color: "#000c00"
            border.color: "#00ff80"
            radius: 12
            Column {
                anchors.centerIn: parent
                spacing: 12
                Text { text: "📻 Radio Mode"; color: "#00ffcc"; font.pixelSize: 28 }
                Repeater {
                    model: ["88.1 FM", "92.3 FM", "99.5 FM", "107.7 FM"]
                    delegate: Button {
                        text: modelData
                        width: 200; height: 50
                        background: Rectangle { color: "#002000"; border.color: "#00ff80"; radius: 8 }
                        contentItem: Text {
                            text: parent.text; color: "#00ffaa"
                            font.pixelSize: 18; anchors.centerIn: parent
                        }
                        onClicked: console.log("Switching to station", modelData)
                    }
                }
            }
        }
    }

    // === BLUETOOTH VIEW ===
    Component {
        id: bluetoothView
        Rectangle {
            anchors.fill: parent
            color: "#001000"
            border.color: "#00ff80"
            radius: 12
            Column {
                anchors.centerIn: parent
                spacing: 20
                Text { text: "📱 Bluetooth Audio"; color: "#00ffcc"; font.pixelSize: 24 }
                Text {
                    id: btStatus
                    text: BluetoothBackend.connected
                            ? "Connected to " + (BluetoothBackend.devices.length ? BluetoothBackend.devices[0].name : "device")
                            : "Bluetooth unavailable"
                    color: BluetoothBackend.connected ? "#00ffaa" : "#ff6666"
                    font.pixelSize: 18
                }
                Row {
                    visible: BluetoothBackend.connected
                    spacing: 25
                    Button { text: "⏮"; width: 60; height: 60; onClicked: BluetoothBackend.previous() }
                    Button { text: "⏯"; width: 60; height: 60; onClicked: BluetoothBackend.playPause() }
                    Button { text: "⏭"; width: 60; height: 60; onClicked: BluetoothBackend.next() }
                }
            }
        }
    }

    Keyboard {
        id: virtualKeyboard
        parent: root
        onCollapsed: console.log("Keyboard closed")
    }


    Connections {
        target: configBackend
        function onConfigChanged(cfg) {
            // --- NEW: react to input-source change ---
            if (cfg["MUSIC_PROGRAMM"] && cfg["MUSIC_PROGRAMM"] !== root.musicInput) {
                root.musicInput = cfg["MUSIC_PROGRAMM"]
                console.log("🎛 Music input changed to", root.musicInput)
            }

            const newSep  = cfg["MUSIC_SEPARATOR"]
            const newArt  = cfg["MUSIC_ARTIST_POS"]
            const newTit  = cfg["MUSIC_TITLE_POS"]
            const newAlb  = cfg["MUSIC_ALBUM_POS"]
            const newPath = cfg["MUSIC_FLDR"]

            let needsReload = false

            if (newPath && newPath !== root.musicBackend.musicRoot) {
                console.log("🎵 Music folder path changed:", newPath)
                root.musicBackend.musicRoot = newPath
                needsReload = true
            }
            if (newSep && newSep !== root.musicSeparator) {
                root.musicSeparator = newSep
                needsReload = true
            }
            if (newArt && parseInt(newArt) !== root.artistIndex) {
                root.artistIndex = parseInt(newArt)
                needsReload = true
            }
            if (newTit && parseInt(newTit) !== root.titleIndex) {
                root.titleIndex = parseInt(newTit)
                needsReload = true
            }
            if (newAlb && parseInt(newAlb) !== root.albumIndex) {
                root.albumIndex = parseInt(newAlb)
                needsReload = true
            }

            if (root.musicInput === "MP3USB" && inputView.item && typeof inputView.item.reloadMusicModel === "function") {
                console.log("🔄 Config fully ready — forcing Mp3usb reload with",
                            "sep", root.musicSeparator,
                            "title", root.titleIndex,
                            "artist", root.artistIndex,
                            "album", root.albumIndex)
                Qt.callLater(() => inputView.item.reloadMusicModel())
            }



        }
    }




    Popup {
        id: settingsPopup
        width: 460
        height: 380
        modal: true
        focus: true

        x: (parent.width - width) / 2
        y: 80

        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "#000c00" }   // dark forest green
                GradientStop { position: 1; color: "#001510" }   // dark teal
            }
            border.color: "#00ff80"
            border.width: 2
            radius: 12
        }

        Column {
            anchors.centerIn: parent
            width: parent.width * 0.9
            spacing: 12

            Text {
                text: "🎵 Music Settings"
                color: "#00ffcc"
                font.pixelSize: 24
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
            }

            // === Music Input Source ===
            Column {
                width: parent.width
                spacing: 4
                Text {
                    text: "Music Input Source:"
                    color: "#80ff99"
                    font.pixelSize: 16
                }
                ComboBox {
                    id: inputSource
                    width: parent.width
                    model: ["MP3USB", "RADIO", "BLUETOOTH"]
                    currentIndex: {
                        const mode = configBackend ? configBackend.get("MUSIC_PROGRAMM") : "MP3USB"
                        return model.indexOf(mode)
                    }
                    onActivated: (idx) => {
                        const val = model[idx]
                        if (configBackend) configBackend.set("MUSIC_PROGRAMM", val)
                        root.musicInput = val    // keep live in root
                    }
                    background: Rectangle {
                        radius: 8
                        color: "#001200"
                        border.color: "#00ffaa"
                        border.width: 1
                    }
                    contentItem: Text {
                        text: parent.displayText
                        color: "#aaffaa"
                        font.pixelSize: 16
                        verticalAlignment: Text.AlignVCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                    }
                }
            }


            // === Folder Path ===
            Column {
                width: parent.width
                spacing: 4
                Text {
                    text: "Music Folder:"
                    color: "#80ff99"
                    font.pixelSize: 16
                }

                Item{
                    width: parent.width
                    opacity: root.musicInput === "MP3USB" ? 1.0 : 0.3
                    enabled: root.musicInput === "MP3USB"
                    TextField {
                        id: folderField
                        anchors.fill: parent
                        onActiveFocusChanged: if (activeFocus) {
                            virtualKeyboard.targetField = folderField
                            virtualKeyboard.open()     // opens Popup modally
                        }
                        text: configBackend ? configBackend.get("MUSIC_FLDR") : ""
                        width: parent.width
                        background: Rectangle {
                            radius: 8
                            color: "#001000"
                            border.color: "#00ff80"
                            border.width: 1
                        }
                        color: "#aaffaa"
                        placeholderText: "Enter music folder path"
                        placeholderTextColor: "#338855"
                    }
                }

            }

            // === Separator ===
            Column {
                width: parent.width * 0.5
                spacing: 4
                Text {
                    text: "Separator Character:"
                    color: "#80ff99"
                    font.pixelSize: 16
                }
                Item {
                    width: parent.width
                    opacity: root.musicInput === "MP3USB" ? 1.0 : 0.3
                    enabled: root.musicInput === "MP3USB"

                    TextField {
                        id: separatorField
                        anchors.fill: parent
                        onActiveFocusChanged: if (activeFocus) {
                            virtualKeyboard.targetField = folderField
                            virtualKeyboard.open()     // opens Popup modally
                        }
                        text: configBackend ? configBackend.get("MUSIC_SEPARATOR") : "-"
                        horizontalAlignment: Text.AlignHCenter
                        background: Rectangle {
                            radius: 8
                            color: "#001200"
                            border.color: "#00ffaa"
                            border.width: 1
                        }
                        color: "#aaffaa"
                        placeholderText: "-"
                        placeholderTextColor: "#338855"
                    }
                }

            }

            // === Positions ===
            Column {
                width: parent.width
                spacing: 4
                Text {
                    text: "Field Positions (Artist / Title / Album):"
                    color: "#80ff99"
                    font.pixelSize: 16
                }

                Row {
                    spacing: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    Item {
                        width: parent.width
                        opacity: root.musicInput === "MP3USB" ? 1.0 : 0.3
                        enabled: root.musicInput === "MP3USB"
                        TextField {
                            id: artistPos
                            anchors.fill: parent
                            onActiveFocusChanged: if (activeFocus) {
                                virtualKeyboard.targetField = folderField
                                virtualKeyboard.open()     // opens Popup modally
                            }
                            width: 60
                            text: configBackend ? configBackend.get("MUSIC_ARTIST_POS") : "1"
                            color: "#aaffaa"
                            horizontalAlignment: Text.AlignHCenter
                            background: Rectangle {
                                color: "#001400"
                                border.color: "#00ffaa"
                                radius: 8
                            }
                        }
                    }


                    Item {
                        width: parent.width
                        opacity: root.musicInput === "MP3USB" ? 1.0 : 0.3
                        enabled: root.musicInput === "MP3USB"

                        TextField {
                            id: titlePos
                            anchors.fill: parent
                            onActiveFocusChanged: if (activeFocus) {
                                virtualKeyboard.targetField = folderField
                                virtualKeyboard.open()     // opens Popup modally
                            }
                            width: 60
                            text: configBackend ? configBackend.get("MUSIC_TITLE_POS") : "2"
                            color: "#aaffaa"
                            horizontalAlignment: Text.AlignHCenter
                            background: Rectangle {
                                color: "#001400"
                                border.color: "#00ffaa"
                                radius: 8
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        opacity: root.musicInput === "MP3USB" ? 1.0 : 0.3
                        enabled: root.musicInput === "MP3USB"
                        TextField {
                            id: albumPos
                            anchors.fill: parent
                            onActiveFocusChanged: if (activeFocus) {
                                virtualKeyboard.targetField = folderField
                                virtualKeyboard.open()     // opens Popup modally
                            }
                            width: 60
                            text: configBackend ? configBackend.get("MUSIC_ALBUM_POS") : "3"
                            color: "#aaffaa"
                            horizontalAlignment: Text.AlignHCenter
                            background: Rectangle {
                                color: "#001400"
                                border.color: "#00ffaa"
                                radius: 8
                            }
                        }
                    }

                }
            }

            // === Buttons ===
            Row {
                spacing: 18
                anchors.horizontalCenter: parent.horizontalCenter
                // anchors.topMargin: 12
                padding: 6

                Button {
                    text: "💾 Save"
                    width: 120; height: 42
                    background: Rectangle {
                        color: "#003300"
                        border.color: "#00ff80"
                        border.width: 2
                        radius: 8
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#00ffcc"
                        font.bold: true
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        if (!configBackend) return
                        configBackend.set("MUSIC_FLDR", folderField.text)
                        configBackend.set("MUSIC_SEPARATOR", separatorField.text)
                        configBackend.set("MUSIC_ARTIST_POS", artistPos.text)
                        configBackend.set("MUSIC_TITLE_POS", titlePos.text)
                        configBackend.set("MUSIC_ALBUM_POS", albumPos.text)
                        settingsPopup.close()
                    }
                }

                Button {
                    text: "❌ Cancel"
                    width: 120; height: 42
                    background: Rectangle {
                        color: "#220000"
                        border.color: "#ff5555"
                        border.width: 2
                        radius: 8
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#ffaaaa"
                        font.bold: true
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: settingsPopup.close()
                }
            }
        }

    }


}
