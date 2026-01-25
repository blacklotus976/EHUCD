// File: Mp3usb.qml
import QtQuick 6.9
import QtQuick.Controls.Basic
import QtMultimedia 6.9
import QtQuick.Layouts 6.9
import "."     // <-- required to access scrollingText from music.qml

Item {
    id: mp3usb
    anchors.fill: parent

    // ==== Properties from parent ====
    property var musicBackend
    property var configBackend
    property var musicModel: []
    property string groupMode: "album"
    property string musicSeparator
    property int artistIndex
    property int titleIndex
    property int albumIndex
    property var currentSong
    property var currentFolder
    property var displayTitle
    property var currentArtist
    property var media
    property var musicCore: (typeof MusicCore !== "undefined" ? MusicCore : null)
    property var expandedFolderSongsRect: null



    onMusicSeparatorChanged: maybeReload()
    onTitleIndexChanged:     maybeReload()
    onArtistIndexChanged:    maybeReload()
    onAlbumIndexChanged:     maybeReload()
    onMusicBackendChanged:   maybeReload()





    // ==== Paging & expansion ====
    property var expandedFolder: null
    property int pageStart: 0
    property int pageSize: 5

    // ----------------- FUNCTIONS -----------------
    function toggleGrouping() {
        // toggle and notify parent for label text update
        groupMode = groupMode === "album" ? "artist" : "album"
        if (parent && parent.groupMode !== undefined)
            parent.groupMode = groupMode
        reloadMusicModel()
    }

    function literalSplit(text, sep) {
        if (!sep || typeof sep !== "string" || sep === "")
            sep = "-"
        const esc = sep.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
        const re = new RegExp("\\s*" + esc + "\\s*")
        return String(text).split(re).map(x => x.trim())
    }


    function indicesReady() {
        return musicSeparator && musicSeparator.length > 0 &&
               Number.isFinite(parseInt(titleIndex)) &&
               Number.isFinite(parseInt(artistIndex)) &&
               Number.isFinite(parseInt(albumIndex))
    }


    function maybeReload() {
        if (musicBackend && indicesReady()) reloadMusicModel()
    }

    function updateCurrentSongDetails(song) {
        if (!song || !mp3usb.musicCore) return

        let cleanTitle = song.title || "Unknown Title"
        // Remove redundant "(by ...)" if the artist matches
        if (cleanTitle.includes("(by")) {
            const inside = cleanTitle.match(/\(by\s+(.+?)\)/i)
            if (inside && inside[1] && song.artist &&
                inside[1].toLowerCase().trim() === song.artist.toLowerCase().trim()) {
                cleanTitle = cleanTitle.replace(/\s*\(by.+?\)/i, "").trim()
            }
        }

        mp3usb.musicCore.currentSong = {
            title: cleanTitle,
            artist: song.artist || "Unknown Artist",
            album: song.album || "Unknown Album",
            fileUrl: song.fileUrl || ""
        }

        mp3usb.displayTitle = cleanTitle
        mp3usb.currentArtist = song.artist || "Unknown Artist"

        console.log("🎵 Updated current song details:", cleanTitle, "by", mp3usb.currentArtist)
    }



    function reloadMusicModel() {
        console.log("🎧 reloadMusicModel with sep:", musicSeparator,
                    "title:", titleIndex, "artist:", artistIndex, "album:", albumIndex)

        if (!musicBackend) { console.warn("⚠️ no musicBackend"); return }
        if (!indicesReady()) { console.warn("⚠️ indices not ready"); return }

        const idxTitle  = Number(titleIndex)
        const idxArtist = Number(artistIndex)
        const idxAlbum  = Number(albumIndex)

        if (!Number.isFinite(idxTitle) || !Number.isFinite(idxArtist) || !Number.isFinite(idxAlbum)) {
            console.warn("⚠️ indices NaN at runtime:", idxTitle, idxArtist, idxAlbum); return
        }

        try {
            let raw = musicBackend.get_music_folders()
            for (let f of raw) {
                if (f && f.songs && typeof f.songs === "object" && !Array.isArray(f.songs))
                    f.songs = Array.from(f.songs)
            }

            mp3usb.musicModel = raw
            const allesFolder = raw.find(f => f && f.name && f.name.trim().toLowerCase() === "alles")
            if (allesFolder) {
                const groups = {}
                for (let s of allesFolder.songs) {
                    if (!s || !s.title) continue

                    let parts = literalSplit(s.title, musicSeparator).map(p => p.trim())
                    while (parts.length < 3) parts.push("")
                    if (!parts[0]) parts[0] = "Missing Title"
                    if (!parts[1]) parts[1] = "Missing Artist"
                    if (!parts[2]) parts[2] = "Missing Album"

                    const title  = parts[idxTitle  - 1]
                    const artist = parts[idxArtist - 1]
                    const album  = parts[idxAlbum  - 1]

                    // --- group key depends on mode ---
                    const key = (groupMode === "artist")
                        ? `artist__${artist.toLowerCase()}`
                        : `album__${album.toLowerCase()}`

                    if (!groups[key])
                        groups[key] = { artistList: new Set(), album, songs: [] }

                    groups[key].artistList.add(artist)
                    groups[key].songs.push({
                        title,
                        artist,
                        album,
                        fileUrl: s.fileUrl,
                        rawTitle: s.title  // keep original for debug
                    })

                }

                const grouped = []

                // === When grouping by ALBUM ===
                if (groupMode === "album") {
                    const singles = []    // songs that don't belong to multi-track albums

                    for (let key in groups) {
                        const g = groups[key]
                        const songCount = g.songs.length
                        const artistCount = g.artistList.size
                        const albumName = g.album && g.album.length ? g.album : "Unknown Album"

                        if (songCount > 1) {
                            // this is a true album folder
                            const display = artistCount === 1
                                ? `${albumName} — ${Array.from(g.artistList)[0]}`
                                : `${albumName} — Various Artists`

                            grouped.push({
                                name: albumName,
                                displayName: display,
                                songs: g.songs.map(song => ({
                                    title: artistCount > 1
                                        ? `${song.title} (by ${song.artist})`
                                        : song.title,
                                    artist: song.artist || "Unknown Artist",
                                    album: song.album || g.album || "Unknown Album",
                                    fileUrl: song.fileUrl
                                }))

                            })
                            console.log("🎵 Album group created:", display, "→", songCount, "songs")
                        } else {
                            // single-song albums go to "Unknown Album"
                            singles.push(...g.songs)
                        }
                    }

                    if (singles.length) {
                        grouped.push({
                            name: "Unknown Album",
                            displayName: "Unknown Album — Various Artists",
                            songs: singles.map(song => ({
                                title: `${song.title} (by ${song.artist})`,
                                artist: song.artist,
                                album: song.album,
                                fileUrl: song.fileUrl
                            }))
                        })
                        console.log("🎵 Singles bucket created: Unknown Album — Various Artists →", singles.length, "songs")
                    }

                    // keep backend-provided "Alles" folder always first
                    for (let f of grouped)
                        console.log("🎵 Folder:", f.displayName, "example song:", f.songs[0])
                    mp3usb.musicModel = [
                        allesFolder,
                        ...raw.filter(f => f.name && f.name.toLowerCase() !== "alles"),
                        ...grouped
                    ]
                    // Make sure every folder has a real JS array for songs
                    for (let f of mp3usb.musicModel) {
                        if (!f.songs) f.songs = []
                        // Convert QVariantList / array-like to proper JS array
                        if (f.songs && typeof f.songs.length === "number" && !Array.isArray(f.songs)) {
                            console.log("🔧 Converting folder.songs to real array:", f.displayName || f.name)
                            f.songs = Array.from(f.songs)
                        }
                    }


                }

                // === When grouping by ARTIST ===
                else if (groupMode === "artist") {
                    const groupedArtists = []
                    for (let key in groups) {
                        const g = groups[key]
                        const artistName = Array.from(g.artistList)[0]
                        groupedArtists.push({
                            name: artistName,
                            displayName: artistName,
                            songs: g.songs.map(song => ({
                                title: song.title,
                                artist: song.artist,
                                album: song.album,
                                fileUrl: song.fileUrl
                            }))

                        })
                        console.log("🎵 Artist group created:", artistName, "→", g.songs.length, "songs")
                    }

                    mp3usb.musicModel = [
                        allesFolder,
                        ...raw.filter(f => f.name && f.name.toLowerCase() !== "alles"),
                        ...groupedArtists
                    ]
                }
            }


            console.log("🎵 Loaded folders:", mp3usb.musicModel.length)
            updateList()
            if (musicModel && musicModel.length)
                folderList.model = musicModel.slice(pageStart, pageStart + pageSize)

        } catch (e) {
            console.error("⚠️ Error loading music folders:", e)
        }
    }

    // === Playback controls and repeat modes ===
    property string repeatMode: "all"   // "one", "all", "list"

    function playNextSong() {
        if (!currentFolder || !currentSong) return
        const list = currentFolder.songs
        const idx = list.indexOf(currentSong)
        if (idx < 0) return

        if (repeatMode === "one") {
            media.source = currentSong.fileUrl
            media.play()
            return
        }

        if (idx === list.length - 1) {
            if (repeatMode === "all") {
                currentSong = list[0]
            } else if (repeatMode === "list") {
                console.log("🎵 End of list (list mode)"); return
            }
        } else {
            currentSong = list[idx + 1]
        }

        if (media) {
            media.source = currentSong.fileUrl
            media.play()
        }
    }

    function playPrevSong() {
        if (!currentFolder || !currentSong) return
        const list = currentFolder.songs
        const idx = list.indexOf(currentSong)
        if (idx < 0) return

        if (repeatMode === "one") {
            media.source = currentSong.fileUrl
            media.play()
            return
        }

        if (idx === 0) {
            if (repeatMode === "all") {
                currentSong = list[list.length - 1]
            } else if (repeatMode === "list") {
                console.log("🎵 Start of list (list mode)"); return
            }
        } else {
            currentSong = list[idx - 1]
        }

        if (media) {
            media.source = currentSong.fileUrl
            media.play()
        }
    }

    function handleSongEnd() {
        playNextSong()
    }


    function updateList() {
        if (!musicModel || !musicModel.length) {
            folderList.model = []
            folderPageLabel.text = "0 / 0"
            return
        }
        const total = Math.ceil(musicModel.length / pageSize)
        const current = Math.floor(pageStart / pageSize) + 1
        folderList.model = musicModel.slice(pageStart, pageStart + pageSize)
        folderPageLabel.text = `${current} / ${total}`
    }

    onPageStartChanged: updateList()

    // ----------------- LAYOUT -----------------
    Row {
        id: mainSplit
        anchors.fill: parent
        anchors.margins: 20
        spacing: 30

        // LEFT PANEL
        Rectangle {
            id: libraryPanel
            width: mainSplit.width * 0.33
            height: mainSplit.height
            color: "#0c140c"
            border.color: "#00ffaa"
            radius: 10

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                Button {
                    id: upBtn
                    text: "▲"
                    width: parent.width
                    height: 36
                    background: Rectangle {
                        radius: 6
                        color: "#062006"
                        border.color: "#00ff80"
                        border.width: 2
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#aaffaa"
                        anchors.centerIn: parent
                        font.pixelSize: 16
                        font.bold: true
                    }
                    onClicked: {
                        if (pageStart > 0) {
                            pageStart = Math.max(pageStart - pageSize, 0)
                            updateList()
                        }
                    }

                }

                ListView {
                    id: folderList
                    width: parent.width - 16
                    height: parent.height - upBtn.height - downBtn.height - 40
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    clip: true
                    delegate: folderDelegate
                }

                Button {
                    id: downBtn
                    text: "▼"
                    width: parent.width
                    height: 36
                    background: Rectangle {
                        radius: 6
                        color: "#062006"
                        border.color: "#00ff80"
                        border.width: 2
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#aaffaa"
                        anchors.centerIn: parent
                        font.pixelSize: 16
                        font.bold: true
                    }
                    onClicked: {
                        const total = musicModel ? musicModel.length : 0
                        if (pageStart + pageSize < total) {
                            pageStart += pageSize
                            updateList()
                        }
                    }

                }

                Text {
                    id: folderPageLabel
                    color: "#00ffaa"
                    font.pixelSize: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "0 / 0"
                }
            }
        }

        // RIGHT PANEL: PLAYER
        Rectangle {
            id: playerArea
            width: mainSplit.width * 0.67
            height: mainSplit.height
            color: "#081008"
            border.color: "#00ff80"
            radius: 12

            Column {
                // anchors.centerIn: parent
                anchors.horizontalCenter: parent.horizontalCenter   // ✅ only horizontalCenter
                anchors.verticalCenter: parent.verticalCenter       // ✅ legal for Column's own anchors
                spacing: 20

                Rectangle {
                    id: albumArt
                    width: 180; height: 180; radius: 12
                    color: "#001100"
                    border.color: "#00ff80"
                    border.width: 2
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "🎵"
                        color: "#00ffcc"
                        font.pixelSize: 80
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }



                // --- Centered song info ---
                Column {
                    id: songInfoColumn
                    width: playerArea.width * 0.8      // ✅ give it real width
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6

                    Text {
                        id: songTitleText
                        text: mp3usb.currentSong
                              ? (mp3usb.currentSong.title || "Unknown Title")
                              : "Unknown Title"
                        color: "#00ffcc"
                        font.pixelSize: 24
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                        wrapMode: Text.NoWrap
                        visible: true
                    }

                    Text {
                        text: mp3usb.currentSong && mp3usb.currentSong.artist
                              ? "by " + mp3usb.currentSong.artist
                              : "by Unknown Artist"
                        color: "#aaffaa"
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                        visible: true
                    }

                    Text {
                        text: mp3usb.currentSong && mp3usb.currentSong.album
                              ? "in " + mp3usb.currentSong.album
                              : "in Unknown Album"
                        color: "#66ffaa"
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                        visible: true
                    }
                }

                Text {
                    text: "DEBUG → " + (mp3usb.currentSong ? mp3usb.currentSong.title + " / " + mp3usb.currentSong.artist : "no song")
                    color: "yellow"
                    font.pixelSize: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                }




                // --- Duration & seek bar ---
                Row {
                    id: durationRow
                    width: 420
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Text {
                        text: mp3usb.musicCore && mp3usb.musicCore.media
                                ? Qt.formatTime(new Date(mp3usb.musicCore.media.position), "m:ss")
                                : "0:00"
                        color: "#80ffaa"
                        font.pixelSize: 14
                        width: 40
                        horizontalAlignment: Text.AlignRight
                    }

                    Slider {
                        id: durationSlider
                        width: 320
                        from: 0
                        to: mp3usb.musicCore && mp3usb.musicCore.media && mp3usb.musicCore.media.duration > 0
                             ? mp3usb.musicCore.media.duration : 1
                        value: mp3usb.musicCore && mp3usb.musicCore.media
                             ? mp3usb.musicCore.media.position : 0
                        height: 14
                        live: true

                        background: Rectangle {
                            id: track
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 6
                            radius: 3
                            color: "#003300"
                            border.color: "#00ff80"
                        }

                        handle: Rectangle {
                            id: handleBall
                            width: 14; height: 14; radius: 7
                            color: "#00ffaa"
                            border.color: "#006600"
                            y: (track.y + track.height/2 - height/2)
                            x: (track.x + (track.width - width) * (durationSlider.visualPosition))
                        }

                        onMoved: {
                            if (mp3usb.musicCore && mp3usb.musicCore.media)
                                mp3usb.musicCore.media.position = value
                        }

                        Timer {
                            interval: 250; running: true; repeat: true
                            onTriggered: {
                                if (!durationSlider.pressed && mp3usb.musicCore && mp3usb.musicCore.media)
                                    durationSlider.value = mp3usb.musicCore.media.position
                            }
                        }
                    }


                    Text {
                        text: mp3usb.musicCore && mp3usb.musicCore.media
                                ? Qt.formatTime(new Date(mp3usb.musicCore.media.duration), "m:ss")
                                : "0:00"
                        color: "#80ffaa"
                        font.pixelSize: 14
                        width: 40
                    }
                }



                // --- Playback controls ---
                Row {
                    spacing: 30
                    anchors.horizontalCenter: parent.horizontalCenter

                    Button {
                        text: "⏮"
                        width: 60; height: 60
                        background: Rectangle { radius: 8; color: "#003000"; border.color: "#00ff80" }
                        contentItem: Text {
                            text: parent.text
                            color: "#aaffaa"
                            anchors.centerIn: parent
                            font.pixelSize: 28
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                        }
                        onClicked: {
                            if (!mp3usb.musicCore) return
                            if (mp3usb.musicCore.playPrevSong) {
                                mp3usb.musicCore.playPrevSong()
                                if (mp3usb.musicCore.currentSong)
                                    mp3usb.updateCurrentSongDetails(mp3usb.musicCore.currentSong)
                            }
                        }
                    }

                    Button {
                        text: (mp3usb.musicCore && mp3usb.musicCore.media &&
                               mp3usb.musicCore.media.playbackState === MediaPlayer.PlayingState) ? "⏸" : "▶"
                        width: 60; height: 60
                        background: Rectangle { radius: 8; color: "#004400"; border.color: "#00ff80" }
                        contentItem: Text {
                            text: parent.text
                            color: "#00ffaa"
                            anchors.centerIn: parent
                            font.pixelSize: 32
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                        }
                        onClicked: {
                            if (!mp3usb.musicCore || !mp3usb.musicCore.media) return
                            if (mp3usb.musicCore.media.playbackState === MediaPlayer.PlayingState)
                                mp3usb.musicCore.media.pause()
                            else
                                mp3usb.musicCore.media.play()
                        }
                    }

                    Button {
                        text: "⏭"
                        width: 60; height: 60
                        background: Rectangle { radius: 8; color: "#003000"; border.color: "#00ff80" }
                        contentItem: Text {
                            text: parent.text
                            color: "#aaffaa"
                            anchors.centerIn: parent
                            font.pixelSize: 28
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                        }
                        onClicked: {
                            if (!mp3usb.musicCore) return
                            if (mp3usb.musicCore.playNextSong) {
                                mp3usb.musicCore.playNextSong()
                                if (mp3usb.musicCore.currentSong)
                                    mp3usb.updateCurrentSongDetails(mp3usb.musicCore.currentSong)
                            }
                        }
                    }

                    Button {
                        text: !mp3usb.musicCore ? "🔂"
                             : (mp3usb.musicCore.repeatMode === "one"  ? "🔂"
                             :  mp3usb.musicCore.repeatMode === "all"  ? "🔁"
                                                                       : "🔁∞")
                        width: 60; height: 60
                        background: Rectangle { radius: 8; color: "#002200"; border.color: "#00ff80" }
                        contentItem: Text {
                            text: parent.text
                            color: "#00ffaa"
                            anchors.centerIn: parent
                            font.pixelSize: 22
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                        }
                        onClicked: {
                            if (!mp3usb.musicCore) return
                            const next = mp3usb.musicCore.repeatMode === "one" ? "all"
                                       : mp3usb.musicCore.repeatMode === "all" ? "loop"
                                       : "one"
                            if (mp3usb.musicCore.setRepeat) mp3usb.musicCore.setRepeat(next)
                            else mp3usb.musicCore.repeatMode = next
                        }
                    }



                }
            }
        }

    }

    // ----------------- DELEGATE -----------------
    Component {
        id: folderDelegate
        Item {
            id: folderItem
            width: parent ? parent.width : 260
            implicitHeight: expanded ? (250 + 60) : 60
            property bool expanded: false
            property var folder: {
                var obj = modelData
                if (obj && obj.songs && typeof obj.songs === "object" && !Array.isArray(obj.songs)) {
                    console.log("🔧 Fixing songs array for", obj.displayName || obj.name)
                    obj.songs = Array.from(obj.songs)
                }
                return obj
            }



            Column {
                width: parent.width
                spacing: 6

                Rectangle {
                    width: parent.width
                    height: 50
                    radius: 6
                    color: expanded ? "#005500" : "#114411"
                    border.color: "#00ffcc"
                    border.width: 2

                    // expand/collapse tap zone
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            expanded = !expanded
                            if (expanded) {
                                folderSongsRect.innerPageStart = 0
                                folderSongsRect.updatePagedSongs()
                            } else if (mp3usb.expandedFolderSongsRect === folderSongsRect) {
                                mp3usb.expandedFolderSongsRect = null
                            }
                        }
                    }

                    Component.onCompleted: {
                        if (expanded)
                            mp3usb.expandedFolderSongsRect = folderSongsRect
                    }



                    // centered scrolling title
                    Loader {
                        id: folderTitle
                        anchors.fill: parent
                        anchors.leftMargin: 50
                        anchors.rightMargin: 60
                        sourceComponent: scrollingText
                        onLoaded: {
                            const count = (folder && folder.songs && typeof folder.songs.length === "number")
                                ? folder.songs.length
                                : 0
                            const name = (folder.displayName && folder.displayName.length > 0)
                                ? folder.displayName
                                : (folder.name || "Unknown")
                            item.text = `📁 ${name} (${count})`
                            item.color = "#ccffcc"
                            item.pixelSize = 18
                        }
                    }


                    // dedicated play button on the right (not part of the loader)
                    Button {
                        id: headerPlay
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        width: 44; height: 34
                        text: "▶"

                        background: Rectangle {
                            radius: 6
                            color: "#003000"
                            border.color: "#00ff80"
                            border.width: 2
                        }

                        contentItem: Text {
                            text: parent.text
                            color: "#aaffaa"
                            anchors.centerIn: parent
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 18
                            font.bold: true
                        }

                        onClicked: {
                            if (folder.songs && folder.songs.length && mp3usb.musicCore && mp3usb.musicCore.media) {
                                const first = folder.songs[0]
                                mp3usb.currentFolder = folder
                                mp3usb.currentSong   = first
                                updateCurrentSongDetails(first)
                                mp3usb.musicCore.currentFolder = folder
                                mp3usb.musicCore.currentSong   = first
                                if (mp3usb.musicCore.playSong)
                                    mp3usb.musicCore.playSong(first.fileUrl)
                                else {
                                    mp3usb.musicCore.media.source = first.fileUrl
                                    mp3usb.musicCore.media.play()
                                }
                            }
                        }
                    }


                }


                Rectangle {
    id: folderSongsRect
    visible: expanded
    width: parent.width
    height: 220
    radius: 8
    color: "#050b05"
    border.color: "#00ffaa"

    property int  innerPageStart: 0
    property int  innerPageSize: 5
    property var  pagedSongs: []
    property var  folder: folderItem.folder
    property string pageLabel: "0 / 0"

    function updatePageLabel() {
        if (!folderSongsRect.folder || !folderSongsRect.folder.songs) {
            folderSongsRect.pageLabel = "0 / 0"; return
        }
        const len = Array.isArray(folderSongsRect.folder.songs)
                  ? folderSongsRect.folder.songs.length : 0
        if (!len) { folderSongsRect.pageLabel = "0 / 0"; return }
        const total   = Math.ceil(len / folderSongsRect.innerPageSize)
        const current = Math.floor(folderSongsRect.innerPageStart / folderSongsRect.innerPageSize) + 1
        folderSongsRect.pageLabel = `${current} / ${total}`
    }

    function updatePagedSongs() {
        const f = folderSongsRect.folder
        if (f && f.songs && typeof f.songs.length === "number" && !Array.isArray(f.songs)) {
            // convert QVariantList/array-like to real JS array
            f.songs = Array.from(f.songs)
        }
        if (f && Array.isArray(f.songs)) {
            const all = f.songs
            folderSongsRect.pagedSongs =
                all.slice(folderSongsRect.innerPageStart,
                          folderSongsRect.innerPageStart + folderSongsRect.innerPageSize)
        } else {
            folderSongsRect.pagedSongs = []
        }
        folderSongsRect.updatePageLabel()
    }

    onInnerPageStartChanged: folderSongsRect.updatePagedSongs()
    onVisibleChanged: if (visible) folderSongsRect.updatePagedSongs()
    Component.onCompleted: folderSongsRect.updatePagedSongs()

    Column {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 6

        Row {
            id: innerPager
            width: parent.width
            height: 36
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            Button {
                text: "▲"
                width: 40; height: 28
                background: Rectangle { radius: 4; color: "#002200"; border.color: "#00ff80" }
                contentItem: Text { text: parent.text; color: "#aaffaa"; anchors.centerIn: parent; font.pixelSize: 16 }
                onClicked: {
                    if (folderSongsRect.innerPageStart > 0)
                        folderSongsRect.innerPageStart =
                            Math.max(folderSongsRect.innerPageStart - folderSongsRect.innerPageSize, 0)
                }
            }

            Text {
                text: folderSongsRect.pageLabel
                color: "#00ffaa"
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }

            Button {
                text: "▼"
                width: 40; height: 28
                background: Rectangle { radius: 4; color: "#002200"; border.color: "#00ff80" }
                contentItem: Text { text: parent.text; color: "#aaffaa"; anchors.centerIn: parent; font.pixelSize: 16 }
                onClicked: {
                    const len = (folderSongsRect.folder && folderSongsRect.folder.songs)
                              ? folderSongsRect.folder.songs.length : 0
                    if (folderSongsRect.innerPageStart + folderSongsRect.innerPageSize < len)
                        folderSongsRect.innerPageStart += folderSongsRect.innerPageSize
                }
            }
        }

        ListView {
            id: innerSongList
            width: parent.width
            height: parent.height - innerPager.height - 10
            anchors.horizontalCenter: parent.horizontalCenter
            model: folderSongsRect.pagedSongs   // << IMPORTANT
            clip: true
            spacing: 4

            delegate: Button {
                width: parent.width
                height: 34
                text: "♪ " + (modelData.title || "(unknown)")
                background: Rectangle {
                    radius: 4
                    color: currentSong === modelData ? "#00ff80" : "#003000"
                    border.color: "#00ff80"
                }
                contentItem: Loader {
                    anchors.centerIn: parent
                    width: parent.width - 20
                    sourceComponent: scrollingText
                    onLoaded: {
                        item.text = parent.text
                        item.color = "#aaffaa"
                        item.pixelSize = 18
                    }
                }
                onClicked: {
                    mp3usb.currentFolder = folderSongsRect.folder
                    mp3usb.currentSong   = modelData
                    mp3usb.updateCurrentSongDetails(modelData)
                    if (mp3usb.musicCore && mp3usb.musicCore.media) {
                        mp3usb.musicCore.currentFolder = folderSongsRect.folder
                        mp3usb.musicCore.currentSong   = modelData
                        mp3usb.musicCore.media.source  = modelData.fileUrl
                        mp3usb.musicCore.media.play()
                    }
                }
            }
        }
    }
}






                Rectangle { width: parent.width; height: 1; color: "#00ffaa33" }



            }
        }
    }


    Component.onCompleted: Qt.callLater(maybeReload)


}
