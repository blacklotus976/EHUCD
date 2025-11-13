import QtQuick 6.9
import QtQuick.Controls 6.9
import QtMultimedia 6.9

Rectangle {
    id: widget
    width: 460
    height: 70
    radius: 12
    color: Qt.rgba(0, 0, 0, 0.70)
    border.color: "#3ba9ff"
    border.width: 1

    // auto-connect to global MusicCore
    readonly property var core: (typeof MusicCore !== "undefined" ? MusicCore : null)
    readonly property var media: core && core.media ? core.media : null

    visible: core
             && core.currentSong
             && core.currentSong.fileUrl
             && core.currentSong.fileUrl !== ""

    // --- LAYOUT ---
    Row {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 14

        // PREV BUTTON
        Button {
            width: 48; height: 48
            text: "⏮"
            background: Rectangle {
                radius: 8
                color: "#005eaa"
            }

            onClicked: {
                if (core && core.playPrevSong)
                    core.playPrevSong()
            }
        }

        // PLAY / PAUSE BUTTON
        Button {
            id: playBtn
            width: 60; height: 48
            text: media && media.playbackState === MediaPlayer.PlayingState ? "⏸" : "▶️"

            background: Rectangle {
                radius: 8
                color: "#0077cc"
            }

            onClicked: {
                if (!media) return
                if (media.playbackState === MediaPlayer.PlayingState)
                    media.pause()
                else
                    media.play()
            }
        }

        // NEXT BUTTON
        Button {
            width: 48; height: 48
            text: "⏭"
            background: Rectangle {
                radius: 8
                color: "#005eaa"
            }

            onClicked: {
                if (core && core.playNextSong)
                    core.playNextSong()
            }
        }

        // TITLE + ARTIST
        Column {
            spacing: 3
            width: 250

            // SLIDING TITLE AREA
            // SLIDING TITLE AREA
            Rectangle {
                id: clip
                width: parent.width
                height: 22
                color: "transparent"
                clip: true

                Text {
                    id: titleText
                    text: core && core.displayTitle ? core.displayTitle : ""
                    font.pixelSize: 16
                    font.bold: true
                    color: "#66caff"

                    // sliding animation
                    SequentialAnimation on x {
                        loops: Animation.Infinite
                        running: clip.width < titleText.width

                        NumberAnimation {
                            from: 0
                            to: -(titleText.width - clip.width)
                            duration: 3500
                            easing.type: Easing.InOutQuad
                        }
                        PauseAnimation { duration: 1000 }
                        NumberAnimation {
                            from: -(titleText.width - clip.width)
                            to: 0
                            duration: 3500
                            easing.type: Easing.InOutQuad
                        }
                        PauseAnimation { duration: 1000 }
                    }
                }
            }


            // ARTIST
            Text {
                id: artistText
                text: core && core.displayArtist ? ("by " + core.displayArtist) : ""
                font.pixelSize: 13
                color: "#aee0ff"
                visible: text.length > 0
            }
        }
    }
}
