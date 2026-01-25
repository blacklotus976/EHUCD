import QtQuick 6.9
import QtQuick.Controls 6.9

ApplicationWindow {
    id: root
    width: 1280
    height: 720
    visible: true
    title: "Car Control Dashboard"

    Loader {
        id: screenLoader
        anchors.fill: parent
    }

    Component.onCompleted: {
        console.debug("Screen Manager initialized")
        changeScreen("main")
    }

    function changeScreen(screenName) {
        console.debug("Switching to screen:", screenName)
        if (screenName === "music") {
            // carMetrics and musicBackend here refer to GLOBAL context properties from Python
            screenLoader.setSource("music.qml", {
                navigator: root,
                musicBackend: musicBackend,
                configBackend: configBackend
            })
        } else if (screenName === "main") {
            screenLoader.setSource("dashboard.qml", {
                navigator: root,
                carMetrics: carMetrics,
                configBackend: configBackend
            })
        } else if (screenName === "dtc&info") {
            screenLoader.setSource("DTCnINFO.qml", {
                navigator: root,
                carMetrics: carMetrics,
                configBackend: configBackend
            })
        }
    }
}
