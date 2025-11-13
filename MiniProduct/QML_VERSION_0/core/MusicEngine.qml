import QtQuick 6.9
import QtMultimedia 6.9

QtObject {
    id: musicCore

    property MediaPlayer media: MediaPlayer {
        id: player
        audioOutput: AudioOutput { id: output; volume: 1.0 }

        // Automatically go to next song when finished
        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.StoppedState && position >= duration - 100) {
                musicCore.handleSongEnd()
            }
        }
    }

    property var currentFolder: null
    property var currentSong: ({ title: "No Song", fileUrl: "" })
    property string currentArtist: ""
    property string displayTitle: "No Song"
    property string repeatMode: "one"   // one | all | loop

    // === Logic ===
    function updateTitleAndArtist() {
        if (!currentSong || !currentSong.title) {
            displayTitle = "No Song"
            currentArtist = ""
            return
        }
        let parts = currentSong.title.split("-")
        if (parts.length >= 2) {
            let titleCandidate = parts[0].trim()
            let artistCandidate = parts.slice(1).join("-").trim()
            if (artistCandidate.length > 0 && artistCandidate.length < 50) {
                currentArtist = artistCandidate
                displayTitle = titleCandidate
                return
            }
        }
        displayTitle = currentSong.title
        currentArtist = ""
    }

    function handleSongEnd() {
        if (!currentFolder || !currentFolder.songs || currentFolder.songs.length === 0) return
        const songs = currentFolder.songs
        let idx = songs.findIndex(s => s.fileUrl === currentSong.fileUrl)

        if (repeatMode === "one") {
            player.position = 0
            player.play()
            console.log("🔁 One mode: restarting", currentSong.title)
            return
        }

        if (repeatMode === "all") {
            if (idx < songs.length - 1) {
                idx++
                currentSong = songs[idx]
                updateTitleAndArtist()
                player.source = currentSong.fileUrl
                player.play()
                console.log("▶ Next song (all mode):", currentSong.title)
            } else {
                console.log("Reached end of album (all mode) → stop.")
                player.stop()
            }
            return
        }

        if (repeatMode === "loop") {
            idx = (idx + 1) % songs.length
            currentSong = songs[idx]
            updateTitleAndArtist()
            player.source = currentSong.fileUrl
            player.play()
            console.log("▶ Next song (loop mode):", currentSong.title)
        }
    }

    function playNextSong() {
        if (!currentFolder || !currentFolder.songs) return
        const songs = currentFolder.songs
        let idx = songs.findIndex(s => s.fileUrl === currentSong.fileUrl)

        if (repeatMode === "one") {
            player.position = 0
            player.play()
            return
        }

        if (repeatMode === "all") {
            if (idx < songs.length - 1) {
                idx++
                currentSong = songs[idx]
                updateTitleAndArtist()
                player.source = currentSong.fileUrl
                player.play()
            }
            return
        }

        if (repeatMode === "loop") {
            idx = (idx + 1) % songs.length
            currentSong = songs[idx]
            updateTitleAndArtist()
            player.source = currentSong.fileUrl
            player.play()
        }
    }

    function playPrevSong() {
        if (!currentFolder || !currentFolder.songs) return
        const songs = currentFolder.songs
        let idx = songs.findIndex(s => s.fileUrl === currentSong.fileUrl)

        if (repeatMode === "one") {
            player.position = 0
            player.play()
            return
        }

        if (repeatMode === "all") {
            if (idx > 0) {
                idx--
                currentSong = songs[idx]
                updateTitleAndArtist()
                player.source = currentSong.fileUrl
                player.play()
            }
            return
        }

        if (repeatMode === "loop") {
            idx = (idx - 1 + songs.length) % songs.length
            currentSong = songs[idx]
            updateTitleAndArtist()
            player.source = currentSong.fileUrl
            player.play()
        }
    }

    function findSongIndex() {
        if (!currentFolder || !currentFolder.songs || !currentSong) return -1
        const songs = currentFolder.songs
        const curUrl = (currentSong.fileUrl || "").toString().toLowerCase()
        for (let i = 0; i < songs.length; i++) {
            if ((songs[i].fileUrl || "").toString().toLowerCase() === curUrl)
                return i
        }
        return -1
    }


    Component.onCompleted: console.log("✅ MusicCore loaded and ready")
}
