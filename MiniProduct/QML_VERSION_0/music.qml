import QtQuick 6.9
import QtQuick.Controls.Basic
import QtMultimedia 6.9



Rectangle {
    id: root
    width: 1280
    height: 720
    color: "#080808"

     Component {
        id: scrollingText
        Item {
            property string text: ""
            property color color: "white"
            property int pixelSize: 20
            property int speed: 60      // smaller = slower scroll (pixels/sec)
            property int pause: 1500
            width: parent ? parent.width : 200
            height: textItem.height

            clip: true

            Text {
                id: textItem
                text: parent.text
                color: parent.color
                font.pixelSize: parent.pixelSize
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }

            NumberAnimation {
                id: scrollAnim
                target: textItem
                property: "x"
                loops: Animation.Infinite
                running: false
                from: 0
                to: 0
                duration: 10000
                easing.type: Easing.Linear
            }

            Timer {
                id: restartTimer
                interval: pause
                repeat: false
                onTriggered: scrollAnim.start()
            }

            onWidthChanged: checkScrolling()
            onTextChanged: checkScrolling()

            function checkScrolling() {
                scrollAnim.stop()
                textItem.x = 0

                if (textItem.contentWidth > width) {
                    const distance = textItem.contentWidth - width
                    const time = (distance / speed) * 1000   // proportional to text length
                    scrollAnim.from = 0
                    scrollAnim.to = -distance
                    scrollAnim.duration = time

                    scrollAnim.running = true
                }
            }

            // Optional: restart the animation periodically
            onVisibleChanged: if (visible) checkScrolling()
        }
    }


    // --- External connections ---
    property var navigator
    property var musicBackend
    property var musicModel: []

    // --- Link to MusicCore context property dynamically ---
    property var media:         (MusicCore ? MusicCore.media         : null)
    property var currentFolder: (MusicCore ? MusicCore.currentFolder : null)
    property var currentSong:   (MusicCore ? MusicCore.currentSong   : null)
    property var currentArtist: (MusicCore ? MusicCore.currentArtist : "")
    property var displayTitle:  (MusicCore ? MusicCore.displayTitle  : "")
    property var repeatMode:    (MusicCore ? MusicCore.repeatMode    : "one")

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
        console.log("🎧 MusicCore bound via context property")
        console.log("🎧 MusicCore type:", typeof MusicCore, "has updateTitleAndArtist:", MusicCore && MusicCore.updateTitleAndArtist)

        if (musicBackend) {
            try {
                let raw = musicBackend.get_music_folders()
                musicModel = raw.map(function(item) {
                    let songs = item.songs

                    // --- Extract artist names ---
                    let artists = songs.map(s => {
                        let parts = s.title.split("-")
                        return parts.length >= 2
                            ? parts[parts.length - 1].trim().toLowerCase().replace(/\s+/g, "")
                            : null
                    }).filter(a => a)

                    let uniqueArtists = [...new Set(artists)]
                    let displayName = item.name

                    if (uniqueArtists.length === 1 && uniqueArtists[0]) {
                        displayName = item.name + " by " + uniqueArtists[0]
                        songs = songs.map(s => {
                            let p = s.title.split("-")
                            if (p.length >= 2) s.title = p.slice(0, -1).join("-").trim()
                            return s
                        })
                    }

                    return {
                        name: item.name,
                        displayName: displayName,
                        songs: songs
                    }
                })
                for (let f of musicModel)
                    console.log("Album loaded:", f.displayName)

                console.log("🎵 Loaded folders:", musicModel.length)
            } catch (err) {
                console.error("⚠️ Error loading music folders:", err)
            }
        } else {
            console.warn("⚠️ musicBackend undefined")
        }
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

    // === LAYOUT: Top bar + main split ===
    Column {
        anchors.fill: parent
        spacing: 0

        // --- TOP BAR ---
        Rectangle {
            id: topBar
            width: parent.width
            height: 60
            color: Qt.rgba(0, 0, 0, 0.4)
            border.color: "#00ff80"
            border.width: 1

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
                        radius: 10; border.width: 2
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
            }
        }

        // --- MAIN SPLIT (1/3 + 2/3) ---
        Row {
            id: mainSplit
            width: parent.width
            height: parent.height - topBar.height
            spacing: 30
            anchors.margins: 20



            // --- LEFT PANEL: Library (1/3) ---
            Rectangle {
                id: libraryPanel
                width: mainSplit.width * 0.33
                height: parent.height - topBar.height - 40
                color: "#101510"
                border.color: "#00ffaa"
                border.width: 2
                radius: 10

                property int pageStart: 0
                property int pageSize: 5

                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    Button {
                        id: upBtn
                        text: "▲"
                        width: parent.width
                        height: 40
                        background: Rectangle { color: "#002200"; border.color: "#00ffaa"; radius: 6 }
                        contentItem: Text { text: "▲"; color: "#00ffaa"; font.pixelSize: 20; anchors.centerIn: parent }
                        onClicked: {
                            if (libraryPanel.pageStart > 0)
                                libraryPanel.pageStart = Math.max(libraryPanel.pageStart - libraryPanel.pageSize, 0)
                        }
                    }

                    ListView {
                        id: folderList
                        width: parent.width - 20
                        height: parent.height - upBtn.height - downBtn.height - 30
                        anchors.horizontalCenter: parent.horizontalCenter
                        orientation: ListView.Vertical
                        model: root.musicModel.slice(libraryPanel.pageStart,
                                                     libraryPanel.pageStart + libraryPanel.pageSize)
                        delegate: folderDelegate
                        spacing: 8
                        clip: true
                        interactive: false
                        Component.onCompleted: console.log("📁 Paged folder list initialized")
                    }

                    Button {
                        id: downBtn
                        text: "▼"
                        width: parent.width
                        height: 40
                        background: Rectangle { color: "#002200"; border.color: "#00ffaa"; radius: 6 }
                        contentItem: Text { text: "▼"; color: "#00ffaa"; font.pixelSize: 20; anchors.centerIn: parent }
                        onClicked: {
                            if (libraryPanel.pageStart + libraryPanel.pageSize < root.musicModel.length)
                                libraryPanel.pageStart += libraryPanel.pageSize
                        }
                    }
                }

                // React when the pageStart changes to reload model
                onPageStartChanged: folderList.model =
                    root.musicModel.slice(pageStart, pageStart + pageSize)
            }



            // --- RIGHT PANEL: Player (2/3) ---
            Rectangle {
                id: playerArea
                width: mainSplit.width * 0.67
                height: mainSplit.height
                color: Qt.rgba(0, 0, 0, 0.35)
                border.color: "#00ff80"
                border.width: 1
                radius: 12

                Column {
                    anchors.centerIn: parent
                    spacing: 18

                    // Album Image Placeholder
                    Rectangle {
                        width: 180; height: 180; radius: 12
                        color: "#001100"
                        border.color: "#00ff80"
                        border.width: 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        Text {
                            anchors.centerIn: parent
                            text: "🎵"
                            color: "#00ffcc"
                            font.pixelSize: 80
                        }
                    }

                    // --- Song title ---
                    Loader {
                        id: titleLoader
                        width: 400
                        anchors.horizontalCenter: parent.horizontalCenter
                        sourceComponent: scrollingText
                        property string key: displayTitle
                        onKeyChanged: {
                            sourceComponent = null
                            sourceComponent = scrollingText
                        }
                        onLoaded: {
                            item.text = displayTitle ? String(displayTitle) : ""
                            item.color = "#00ffcc";
                            item.font.pixelSize = 24;
                            item.font.bold = true;
                        }
                    }

                    // --- Artist name (only visible if found) ---
                    Loader {
                        id: artistLoader
                        width: 400
                        anchors.horizontalCenter: parent.horizontalCenter
                        sourceComponent: scrollingText
                        property string key: currentArtist
                        onKeyChanged: {
                            sourceComponent = null
                            sourceComponent = scrollingText
                        }
                        visible: !!(currentArtist && currentArtist.length > 0)
                        onLoaded: {
                            const a = currentArtist ? "by " + currentArtist : "";
                            item.text = String(a);
                            item.color = "#99ffcc";
                            item.font.pixelSize = 18;
                        }
                    }

                    // --- Album / playlist ---
                    Loader {
                        id: albumLoader
                        width: 400
                        anchors.horizontalCenter: parent.horizontalCenter
                        sourceComponent: scrollingText
                        property string key: currentFolder ? currentFolder.displayName : ""
                        onKeyChanged: {
                            sourceComponent = null
                            sourceComponent = scrollingText
                        }
                        onLoaded: {
                            const albumText = (currentFolder && currentFolder.displayName)
                                ? currentFolder.displayName
                                : (currentFolder && currentFolder.name)
                                    ? "Album / Playlist: " + currentFolder.name
                                    : ""
                            item.text = albumText
                            item.color = "#66ffaa"
                            item.font.pixelSize = 16
                        }
                    }





                    // --- Progress Bar ---
                    Rectangle {
                        id: progressOuter
                        width: 500; height: 10
                        radius: 5
                        color: "#003300"
                        border.color: "#00ff80"
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            id: progressInner
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            radius: 4
                            width: (MusicCore && MusicCore.media && MusicCore.media.duration > 0)
                               ? (MusicCore.media.position / MusicCore.media.duration) * parent.width
                               : 0
                            color: "#00ff80"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed: {
                                if (media && media.duration > 0) {
                                    const pos = mouse.x / progressOuter.width
                                    media.position = pos * media.duration
                                }
                            }
                            onPositionChanged: {
                                if (pressed && media && media.duration > 0) {
                                    const pos = mouse.x / progressOuter.width
                                    media.position = pos * media.duration
                                }
                            }
                        }
                    }


                    // Controls
                    Row {
                        spacing: 35
                        anchors.horizontalCenter: parent.horizontalCenter

                        Button {
                            text: "⏮"
                            width: 60; height: 60
                            background: Rectangle { width: 60; height: 60; radius: 30; border.color: "#00ffcc"; color: "transparent" }
                            contentItem: Text {
                                text: parent.text; color: "#00ffcc"; font.pixelSize: 22
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: playPrevSong()
                        }

                        Button {
                            text: (media && media.playbackState === MediaPlayer.PlayingState) ? "⏸" : "▶️"
                            width: 70; height: 70
                            background: Rectangle { width: 70; height: 70; radius: 35; color: "#00ff80" }
                            contentItem: Text {
                                text: parent.text; color: "black"; font.pixelSize: 28
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: {
                                if (!media) return;
                                if (media.playbackState === MediaPlayer.PlayingState) media.pause();
                                else media.play();
                            }
                        }

                        Button {
                            text: "⏭"
                            width: 60; height: 60
                            background: Rectangle { width: 60; height: 60; radius: 30; border.color: "#00ffcc"; color: "transparent" }
                            contentItem: Text {
                                text: parent.text; color: "#00ffcc"; font.pixelSize: 22
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: playNextSong()
                        }

                        // Mode Button: off → one → loop (playlist) → all (play once) → off
                        Button {
                            id: modeBtn
                            width: 60; height: 60
                            text: repeatMode === "one" ? "🔂"
                                  : (repeatMode === "loop" ? "🔁" : "🔄")
                            background: Rectangle {
                                width: 60; height: 60; radius: 30
                                border.color: "#00ffaa"
                                color: "transparent"
                            }
                            contentItem: Text {
                                text: parent.text
                                color: "#00ffaa"
                                font.pixelSize: 22
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: {
                                if (MusicCore.repeatMode === "one") MusicCore.repeatMode = "all"
                                else if (MusicCore.repeatMode === "all") MusicCore.repeatMode = "loop"
                                else MusicCore.repeatMode = "one"
                                console.log("Repeat mode set to:", MusicCore.repeatMode)
                            }
                        }

                    }
                }
            }
        }
    }



    // --- FOLDER DELEGATE ---
    Component {
        id: folderDelegate
        Item {
            id: folderItem
            width: parent ? parent.width : 240
            implicitHeight: expanded ? (250 + 60) : 60
            property bool expanded: false
            property var folder: modelData

            Column {
                width: parent.width
                spacing: 6

                // --- Album Header ---
                Rectangle {
                    id: header
                    width: parent.width
                    height: 50
                    radius: 6
                    color: "#114411"
                    border.color: "#00ffcc"
                    border.width: 2

                    Row {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Loader {
                            sourceComponent: scrollingText
                            width: parent.width * 0.7
                            onLoaded: {
                                item.text = "📁 " + (folder.displayName ? folder.displayName : folder.name)
                                item.color = "white"
                                item.font.pixelSize = 20
                                item.font.bold = true
                            }
                        }


                        Button {
                            text: "▶"
                            width: 50; height: 30
                            background: Rectangle { color: "#00ff80"; radius: 6 }
                            contentItem: Text {
                                text: parent.text; color: "black"; font.pixelSize: 16
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: {
                                if (!MusicCore) return;
                                MusicCore.currentFolder = folder;
                                MusicCore.currentSong = folder.songs[0];
                                MusicCore.updateTitleAndArtist();
                                if (MusicCore.media) {
                                    MusicCore.media.source = MusicCore.currentSong.fileUrl;
                                    MusicCore.media.play();
                                }
}
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: folderItem.expanded = !folderItem.expanded
                    }
                }

                // --- SONG BOX ---
                Rectangle {
                    id: songBox
                    visible: folderItem.expanded
                    width: parent.width
                    height: 250
                    radius: 8
                    color: "#081008"
                    border.color: "#00ffaa"
                    border.width: 1
                    property int songPageStart: 0
                    property int songPageSize: 5

                    Column {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4

                        // UP BUTTON
                        Button {
                            text: "▲"
                            visible: folder.songs.length > songBox.songPageSize
                            width: parent.width
                            height: 30
                            background: Rectangle { color: "#002200"; border.color: "#00ffaa"; radius: 6 }
                            contentItem: Text {
                                text: "▲"
                                color: "#00ffaa"
                                font.pixelSize: 18
                                anchors.centerIn: parent
                            }
                            onClicked: {
                                if (songBox.songPageStart > 0)
                                    songBox.songPageStart = Math.max(songBox.songPageStart - songBox.songPageSize, 0)
                            }
                        }

                        // SONG LIST
                        Repeater {
                            model: folder.songs.slice(songBox.songPageStart, songBox.songPageStart + songBox.songPageSize)
                            delegate: Button {
                                width: parent.width
                                height: 36
                                text: "♪ " + modelData.title
                                background: Rectangle {
                                    radius: 4
                                    color: root.currentSong === modelData ? "#00ff80" : "#002800"
                                    border.color: "#00ff80"
                                }
                                contentItem: Loader {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    width: parent.width - 16
                                    sourceComponent: scrollingText
                                    onLoaded: {
                                        item.text = parent.text
                                        item.color = root.currentSong === modelData ? "black" : "#aaffaa"
                                        item.font.pixelSize = 14
                                    }
                                }

                                onClicked: {
                                    if (!MusicCore) return;
                                    MusicCore.currentFolder = folder;
                                    MusicCore.currentSong = modelData;
                                    MusicCore.updateTitleAndArtist();
                                    if (MusicCore.media) {
                                        MusicCore.media.source = modelData.fileUrl;
                                        MusicCore.media.play();
                                    }
                                }
                            }
                        }

                        // DOWN BUTTON
                        Button {
                            text: "▼"
                            visible: folder.songs.length > songBox.songPageSize
                            width: parent.width
                            height: 30
                            background: Rectangle { color: "#002200"; border.color: "#00ffaa"; radius: 6 }
                            contentItem: Text {
                                text: "▼"
                                color: "#00ffaa"
                                font.pixelSize: 18
                                anchors.centerIn: parent
                            }
                            onClicked: {
                                if (songBox.songPageStart + songBox.songPageSize < folder.songs.length)
                                    songBox.songPageStart += songBox.songPageSize
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#00ffaa33" } // separator
            }
        }
    }
}
