import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick3D

Window {
    id: root
    width: 1100; height: 950; visible: true; title: "Wardrobe Architect v2.1.0"
    color: "#f0f2f5"
    function refreshUI() {
    if (!wardrobeManager) return;

    let idx = bar.currentIndex;
    let cfg = wardrobeManager.get_config_at(idx);

    if (cfg) {
        // Reverse Map: Hex -> Name
        let hexToName = {
            "#ffffff": "White", "#808080": "Grey", "#7f8c8d": "Grey",
            "#b5905d": "Oak", "#d4a373": "Oak", "#222222": "Black"
        };

        // Try to get the name from the hex, otherwise use the string directly
        let dColorName = hexToName[cfg.door_color] || cfg.door_color;
        let fColorName = hexToName[cfg.frame_color] || cfg.frame_color;

        // Now find() will work because it's looking for "Grey" not "#7f8c8d"
        doorColorDrop.cb.currentIndex = doorColorDrop.cb.find(dColorName);
        frameColorDrop.cb.currentIndex = frameColorDrop.cb.find(fColorName);
        hingeSide.cb.currentIndex = hingeSide.cb.find(cfg.door_side || "None");

        // Sync inputs
        wBox.tf.text = (cfg.w || 600).toString();
        hBox.tf.text = (cfg.h || 2000).toString();
        dBox.tf.text = (cfg.d || 600).toString();

        // Update properties for Canvas/3D
        wBox.value = cfg.w; hBox.value = cfg.h; dBox.value = cfg.d;
    }
    mainCanvas.requestPaint();
}

    property string viewMode: "Front"
    property bool doorOpen: false
    property bool contrastBackFrame: false
    property bool isMerged: false // Toggle for Single vs Merged

    // Thickness parameters
    property real sideThickness: 18.0
    property real bottomThickness: 25.0

    readonly property bool is3D: viewMode === "3D View"
    readonly property bool isDepth2D: viewMode === "Depth 2D"

    function getActualColor(name) {
        let map = {"Oak": "#b5905d", "White": "#ffffff", "Black": "#222222", "Grey": "#808080"};
        let c = map[name]; return c ? c : name.toLowerCase();
    }

    function getValidHinges() {
        if (typeof wardrobeManager === 'undefined') return ["Left", "Right", "None"];
        let list = ["Left", "Right", "None"];
        if (wardrobeManager.get_neighbor_side(-1) === "Right") list = list.filter(item => item !== "Left");
        if (wardrobeManager.get_neighbor_side(1) === "Left") list = list.filter(item => item !== "Right");
        return list;
    }


    Connections {
        target: wardrobeManager
        // ignoreUnknownSignals: true

        // This triggers whenever the tab is switched OR data is changed
        function onActiveIndexChanged() {
            refreshUI()
        }

        function onDataChanged() {
            refreshUI()
        }
    }
    component ConfigDrop : Column {
        property string title: ""; property var modelData; property string settingKey
        property alias cb: combo // Allows us to set currentIndex from refreshUI
        spacing: 5
        Label { text: title; font.bold: true; color: "#555" }
        ComboBox {
            id: combo; width: 160; model: parent.modelData
            onActivated: { wardrobeManager.update_setting(parent.settingKey, currentText); mainCanvas.requestPaint() }
        }
    }

    component CompactInput : Column {
        property string label: ""; property real value: 600.0; property string sKey
        property alias tf: inputField // Allows us to set text from refreshUI
        spacing: 5
        Label { text: label; font.bold: true; color: "#555" }
        TextField {
            id: inputField
            width: 100; text: parent.value.toString(); placeholderText: "mm"; selectByMouse: true
            validator: DoubleValidator { bottom: 100; top: 3000 }
            onEditingFinished: {
                let val = parseFloat(text);
                if (!isNaN(val)) {
                    parent.value = val;
                    if (wardrobeManager) wardrobeManager.update_setting(parent.sKey, text);
                    mainCanvas.requestPaint();
                }
            }
        }
    }

    readonly property string doorColorStr: (wardrobeManager && wardrobeManager.doorColor) ? wardrobeManager.doorColor : "White"
    readonly property string frameColorStr: (wardrobeManager && wardrobeManager.frameColor) ? wardrobeManager.frameColor : "Grey"

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 20; spacing: 10

        RowLayout {
            Layout.fillWidth: true; spacing: 5
            TabBar {
                id: bar; Layout.fillWidth: true
                currentIndex: wardrobeManager ? wardrobeManager.activeIndex : 0
                Repeater {
                    // Inside TabBar -> Repeater
                    model: (wardrobeManager && wardrobeManager.tabCount !== undefined) ? wardrobeManager.tabCount : 0
                    TabButton {
                        width: 160
                        contentItem: RowLayout {
                            spacing: 0
                            ToolButton { text: "‹"; visible: index > 0; onClicked: wardrobeManager.moveBox(index, index - 1) }
                            Text { text: "Box " + (index + 1); horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true; font.bold: bar.currentIndex === index }
                            ToolButton { text: "›"; visible: index < ((typeof wardrobeManager !== 'undefined' ? wardrobeManager.tabCount : 1) - 1); onClicked: wardrobeManager.moveBox(index, index + 1) }
                            ToolButton { text: "×"; visible: index > 0; onClicked: wardrobeManager.removeBox(index) }
                        }
                        onClicked: { wardrobeManager.setActiveIndex(index); doorOpen = false; root.refreshUI(); }
                    }
                }
            }
            Button { text: "+ Add"; onClicked: if(wardrobeManager) wardrobeManager.addBox() }
        }

        Rectangle {
            id: configPanel
            Layout.fillWidth: true; Layout.preferredHeight: 140; color: "white"; radius: 10; border.color: "#dce1e8"
            onVisibleChanged: if(visible) refreshUI()

            GridLayout {
                anchors.fill: parent; anchors.margins: 15; columns: 5; rowSpacing: 10
                ConfigDrop { id: doorColorDrop; title: "Door Color"; modelData: ["White", "Grey", "Oak", "Black"]; settingKey: "door_color" }
                ConfigDrop { id: frameColorDrop; title: "Frame Color"; modelData: ["Grey", "White", "Black", "Oak"]; settingKey: "frame_color" }
                ConfigDrop { id: hingeSide; title: "Hinge Side"; modelData: ["Left", "Right", "None"]; settingKey: "door_side" }
                Column {
                    spacing: 5
                    Label { text: "Back Contrast"; font.bold: true; color: "#555" }
                    Switch { checked: root.contrastBackFrame; onToggled: root.contrastBackFrame = checked }
                }
                Row {
                    Layout.alignment: Qt.AlignBottom; spacing: 10
                    // We removed the 'value' property binding to prevent the tabs from "leaking" values
                    CompactInput { id: wBox; label: "W"; sKey: "width" }
                    CompactInput { id: hBox; label: "H"; sKey: "height" }
                    CompactInput { id: dBox; label: "D"; sKey: "depth" }
                }
            }
        }

        Rectangle {
            id: environment
            Layout.fillWidth: true; Layout.fillHeight: true; color: "#2c3e50"; radius: 10; clip: true
            property real userScale: 1.0
            readonly property real finalScl: ((height * 0.4) / 2000) * userScale

            ComboBox {
                id: modeSelect
                anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 15; z: 10
                model: ["Front", "Depth 2D", "3D View"]
                onActivated: {
                    root.viewMode = currentText; // This changes the 'is3D' and 'isDepth2D' properties
                    doorOpen = false;
                    mainCanvas.requestPaint();
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 20; z: 10
                width: 160; height: 45; color: "#aa000000"; radius: 8; visible: root.is3D
                Column {
                    anchors.centerIn: parent
                    Text { text: "Dimensions"; color: "#aaa"; font.pixelSize: 10; anchors.horizontalCenter: parent.horizontalCenter }
                    Text {
                        text: wBox.value + " x " + hBox.value + " x " + dBox.value + " mm"
                        color: "white"; font.bold: true; font.pixelSize: 13
                    }
                }
            }

            Item {
                id: viewport
                anchors.fill: parent
                function getBoxXPosition(idx) {
                    if (!wardrobeManager) return 0;
                    let totalW = wardrobeManager.get_total_width();
                    let offset = 0;
                    for (let i = 0; i < idx; i++) {
                        offset += wardrobeManager.get_box_width(i);
                    }
                    return (offset + wardrobeManager.get_box_width(idx) / 2) - (totalW / 2);
                }
                // Single/Merged Toggle Button (Only visible in 3D)
                Button {
                    anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 15
                    z: 20; visible: root.is3D
                    text: root.isMerged ? "View: Merged" : "View: Single"
                    onClicked: root.isMerged = !root.isMerged
                }

                Canvas {
                    id: mainCanvas; anchors.fill: parent; visible: !root.is3D

                    function drawDim(ctx, x1, y1, x2, y2, label) {
                        var headlen = 8 * environment.userScale;
                        var angle = Math.atan2(y2-y1, x2-x1);

                        // Main Line
                        ctx.beginPath();
                        ctx.moveTo(x1, y1);
                        ctx.lineTo(x2, y2);

                        // Arrow at End (x2, y2)
                        ctx.lineTo(x2 - headlen * Math.cos(angle - Math.PI/6), y2 - headlen * Math.sin(angle - Math.PI/6));
                        ctx.moveTo(x2, y2);
                        ctx.lineTo(x2 - headlen * Math.cos(angle + Math.PI/6), y2 - headlen * Math.sin(angle + Math.PI/6));

                        // Arrow at Start (x1, y1)
                        ctx.moveTo(x1, y1);
                        ctx.lineTo(x1 + headlen * Math.cos(angle - Math.PI/6), y1 + headlen * Math.sin(angle - Math.PI/6));
                        ctx.moveTo(x1, y1);
                        ctx.lineTo(x1 + headlen * Math.cos(angle + Math.PI/6), y1 + headlen * Math.sin(angle + Math.PI/6));

                        ctx.stroke();

                        ctx.save();
                        ctx.translate((x1 + x2) / 2, (y1 + y2) / 2);
                        if (Math.abs(y2 - y1) > Math.abs(x2 - x1)) {
                            ctx.rotate(-Math.PI / 2);
                            ctx.fillText(label, 0, -10);
                        } else {
                            ctx.fillText(label, 0, -10);
                        }
                        ctx.restore();
                    }

                    onPaint: {
                        var ctx = getContext("2d"); ctx.reset();
                        var scl = environment.finalScl;
                        var rw = wBox.value * scl; var rh = hBox.value * scl; var rs = dBox.value * 0.4 * scl;
                        ctx.font = "bold " + Math.max(10, 14 * environment.userScale) + "px sans-serif";
                        ctx.lineWidth = 1.5; ctx.textAlign = "center";
                        var fCol = getActualColor(frameColorStr); var lineCol = (fCol === "#ffffff") ? "black" : "white";

                        if (root.isDepth2D) {
                            var ox = (parent.width - rw) / 2 + (rs / 2); var oy = (parent.height - rh) / 2 + (rs / 2);
                            var bx = ox - rs; var by = oy - rs;

                            // Draw the 2D "Depth" perspective shapes
                            ctx.fillStyle = fCol; ctx.fillRect(bx, by, rw, rh); ctx.strokeStyle = lineCol; ctx.strokeRect(bx, by, rw, rh);
                            ctx.beginPath(); ctx.moveTo(bx, by); ctx.lineTo(ox, oy); ctx.lineTo(ox, oy + rh); ctx.lineTo(bx, by + rh); ctx.closePath(); ctx.fill(); ctx.stroke();
                            ctx.beginPath(); ctx.moveTo(bx, by); ctx.lineTo(ox, oy); ctx.lineTo(ox + rw, oy); ctx.lineTo(bx + rw, by); ctx.closePath(); ctx.fill(); ctx.stroke();
                            ctx.fillStyle = root.contrastBackFrame ? "grey" : fCol; ctx.fillRect(ox, oy, rw, rh); ctx.strokeRect(ox, oy, rw, rh);

                            ctx.strokeStyle = "#00f2ff"; ctx.fillStyle = "#00f2ff";
                            var dOff = 50 * environment.userScale;

                            // Width & Height
                            drawDim(ctx, ox, oy + rh + dOff, ox + rw, oy + rh + dOff, (wBox.value/10) + " cm");
                            drawDim(ctx, ox + rw + dOff, oy, ox + rw + dOff, oy + rh, (hBox.value/10) + " cm");

                            // UPDATED: Depth axis moved to Bottom-Left side
                            // Using bx, by+rh (Outer Bottom Left) to ox, oy+rh (Inner Bottom Left)
                            // Added a small Y-offset (20 * scale) to push it slightly below the object
                            var depthYOffset = 20 * environment.userScale;
                            drawDim(ctx, bx, by + rh + depthYOffset, ox, oy + rh + depthYOffset, (dBox.value/10) + " cm");

                        } else if (root.viewMode === "Front") {
                            var fox = (parent.width - rw) / 2; var foy = (parent.height - rh) / 2;
                            ctx.fillStyle = fCol; ctx.fillRect(fox, foy, rw, rh); ctx.strokeStyle = lineCol; ctx.strokeRect(fox, foy, rw, rh);

                            ctx.strokeStyle = "white"; ctx.fillStyle = "white";
                            var fOff = 50 * environment.userScale;

                            // Width dimension: if door is open, double the line length
                            var hinge = hingeSide.cb.currentText;
                            var xStart = fox;
                            var xEnd = fox + rw;
                            var labelText = (wBox.value/10) + " cm";

                            if (doorOpen && hinge !== "None") {
                                labelText += " (*2)";
                                if (hinge === "Left") xStart -= rw;
                                else xEnd += rw;
                            }

                            drawDim(ctx, xStart, foy + rh + fOff, xEnd, foy + rh + fOff, labelText);
                            drawDim(ctx, fox + rw + fOff, foy, fox + rw + fOff, foy + rh, (hBox.value/10) + " cm");
                        }
                    }
                }

                // View3D {
                //     id: view3D
                //     anchors.fill: parent; visible: root.is3D
                //     environment: SceneEnvironment { clearColor: "#2c3e50"; backgroundMode: SceneEnvironment.Color }
                //
                //     Node {
                //         id: sceneRoot
                //         eulerRotation.y: -25; eulerRotation.x: -15
                //         readonly property real scaleFactor: 0.2
                //         readonly property real rw: wBox.value * scaleFactor
                //         readonly property real rh: hBox.value * scaleFactor
                //         readonly property real rd: dBox.value * scaleFactor
                //
                //         Node {
                //             id: wardrobeShell
                //             Model { position: Qt.vector3d(0, 0, -sceneRoot.rd/2); scale: Qt.vector3d(sceneRoot.rw/100, sceneRoot.rh/100, 0.01); source: "#Cube"; materials: [ PrincipledMaterial { baseColor: root.contrastBackFrame ? "grey" : getActualColor(root.frameColorStr); lighting: PrincipledMaterial.NoLighting } ] }
                //             Model { position: Qt.vector3d(-sceneRoot.rw/2, 0, 0); scale: Qt.vector3d(0.01, sceneRoot.rh/100, sceneRoot.rd/100); source: "#Cube"; materials: [ PrincipledMaterial { baseColor: getActualColor(root.frameColorStr); lighting: PrincipledMaterial.NoLighting } ] }
                //             Model { position: Qt.vector3d(sceneRoot.rw/2, 0, 0); scale: Qt.vector3d(0.01, sceneRoot.rh/100, sceneRoot.rd/100); source: "#Cube"; materials: [ PrincipledMaterial { baseColor: getActualColor(root.frameColorStr); lighting: PrincipledMaterial.NoLighting } ] }
                //             Model { position: Qt.vector3d(0, sceneRoot.rh/2, 0); scale: Qt.vector3d(sceneRoot.rw/100, 0.01, sceneRoot.rd/100); source: "#Cube"; materials: [ PrincipledMaterial { baseColor: getActualColor(root.frameColorStr); lighting: PrincipledMaterial.NoLighting } ] }
                //             Model { position: Qt.vector3d(0, -sceneRoot.rh/2, 0); scale: Qt.vector3d(sceneRoot.rw/100, 0.01, sceneRoot.rd/100); source: "#Cube"; materials: [ PrincipledMaterial { baseColor: getActualColor(root.frameColorStr); lighting: PrincipledMaterial.NoLighting } ] }
                //         }
                //
                //         Node {
                //             id: hingePivot3D
                //             property bool isLeft: hingeSide.cb.currentText === "Left"
                //             visible: hingeSide.cb.currentText !== "None"
                //             x: isLeft ? -sceneRoot.rw/2 : sceneRoot.rw/2
                //             z: sceneRoot.rd/2
                //             eulerRotation.y: doorOpen ? (isLeft ? -120 : 120) : 0
                //             Behavior on eulerRotation.y { NumberAnimation { duration: 400 } }
                //
                //             Model {
                //                 id: doorModel3D
                //                 x: parent.isLeft ? sceneRoot.rw/2 : -sceneRoot.rw/2
                //                 scale: Qt.vector3d(sceneRoot.rw/100, sceneRoot.rh/100, 0.02)
                //                 source: "#Cube"
                //                 materials: [ PrincipledMaterial { baseColor: getActualColor(root.doorColorStr); lighting: PrincipledMaterial.NoLighting } ]
                //
                //                 Model {
                //                     id: knob3D
                //                     source: "#Sphere"
                //                     readonly property real widthRatio: wBox.value / 600
                //                     readonly property real heightRatio: hBox.value / 1800
                //                     readonly property real dynamicFactor: ((widthRatio + heightRatio) / 2) * 0.25
                //                     scale: Qt.vector3d(dynamicFactor / (sceneRoot.rw/100), dynamicFactor / (sceneRoot.rh/100), dynamicFactor / 0.02)
                //                     property real margin: (sceneRoot.rw * 0.08) / (sceneRoot.rw/100)
                //                     readonly property real localRadius: 50 * (dynamicFactor / 0.02)
                //                     position: Qt.vector3d(parent.parent.isLeft ? (50 - margin) : (-50 + margin), 0, 50 + localRadius)
                //                     materials: [ PrincipledMaterial { baseColor: "gold"; lighting: PrincipledMaterial.NoLighting } ]
                //                 }
                //             }
                //         }
                //     }
                //     PerspectiveCamera {
                //         z: 600 / environment.userScale; clipFar: 5000; clipNear: 1
                //     }
                // }


                View3D {
                    id: view3D
                    anchors.fill: parent; visible: root.is3D
                    environment: SceneEnvironment { clearColor: "#2c3e50"; backgroundMode: SceneEnvironment.Color }

                    Node {
                        id: sceneRoot
                        eulerRotation.y: -25; eulerRotation.x: -15

                        Repeater3D {
                            id: wardrobeRepeater
                            model: (root.isMerged && wardrobeManager) ? wardrobeManager.tabCount : 1

                            Node {
                                id: boxInstance
                                readonly property int boxIdx: root.isMerged ? index : bar.currentIndex
                                readonly property real sF: 0.2

                                // We use a local property to hold the config so we can log it
                                property var cfg: (root.isMerged && wardrobeManager) ? wardrobeManager.get_config_at(index) : null

                                // --- DEBUG LOGGER ---
                                onCfgChanged: {
                                    if (cfg) {
                                        console.log("DEBUG [Box " + boxIdx + "]: Config updated. Side: " + cfg.door_side +
                                                    ", Color: " + cfg.door_color + ", Width: " + cfg.w)
                                    } else {
                                        console.log("DEBUG [Box " + boxIdx + "]: Config is NULL (using UI defaults)")
                                    }
                                }

                                Connections {
                                    target: wardrobeManager
                                    function onDataChanged() {
                                        // Force-refresh the local config variable
                                        boxInstance.cfg = wardrobeManager.get_config_at(boxInstance.boxIdx)
                                        console.log("DEBUG [Box " + boxIdx + "]: Manager data changed. Re-fetching config...")
                                    }
                                }

                                readonly property real rw: (cfg && cfg.w ? cfg.w : wBox.value) * sF
                                readonly property real rh: (cfg && cfg.h ? cfg.h : hBox.value) * sF
                                readonly property real rd: (cfg && cfg.d ? cfg.d : dBox.value) * sF

                                x: {
                                    if (!root.isMerged || !wardrobeManager) return 0;

                                    let offset = 0;
                                    let totalWidth = wardrobeManager.get_total_width();

                                    // Sum widths of all boxes before this one
                                    for (let i = 0; i < index; i++) {
                                        offset += wardrobeManager.get_box_width(i);
                                    }

                                    // Center the entire row by subtracting half total width
                                    // Then add half of THIS box's width to find its center
                                    return (offset + (wardrobeManager.get_box_width(index) / 2) - (totalWidth / 2)) * sF
                                }
                                y: rh / 2
                                z: rd / 2

                                Node {
                                    id: wardrobeShell
                                    // Adding pickable: true to the back panel makes clicking much more reliable
                                    Model {
                                        id: backPanel
                                        pickable: true
                                        position: Qt.vector3d(0, 0, -boxInstance.rd/2)
                                        scale: Qt.vector3d(boxInstance.rw/100, boxInstance.rh/100, 0.01)
                                        source: "#Cube"
                                        materials: [ PrincipledMaterial {
                                            baseColor: root.contrastBackFrame ? "grey" : getActualColor(cfg ? cfg.frame_color : frameColorStr)
                                            lighting: PrincipledMaterial.NoLighting
                                        } ]
                                    }
                                    // SIDES
                                    Model {
                                        position: Qt.vector3d(-boxInstance.rw/2, 0, 0); scale: Qt.vector3d(0.01, boxInstance.rh/100, boxInstance.rd/100)
                                        source: "#Cube"; materials: [ PrincipledMaterial { baseColor: getActualColor(cfg ? cfg.frame_color : frameColorStr); lighting: PrincipledMaterial.NoLighting } ]
                                    }
                                    Model {
                                        position: Qt.vector3d(boxInstance.rw/2, 0, 0); scale: Qt.vector3d(0.01, boxInstance.rh/100, boxInstance.rd/100)
                                        source: "#Cube"; materials: [ PrincipledMaterial { baseColor: getActualColor(cfg ? cfg.frame_color : frameColorStr); lighting: PrincipledMaterial.NoLighting } ]
                                    }
                                    // TOP & BOTTOM
                                    Model {
                                        position: Qt.vector3d(0, boxInstance.rh/2, 0); scale: Qt.vector3d(boxInstance.rw/100, 0.01, boxInstance.rd/100)
                                        source: "#Cube"; materials: [ PrincipledMaterial { baseColor: getActualColor(cfg ? cfg.frame_color : frameColorStr); lighting: PrincipledMaterial.NoLighting } ]
                                    }
                                    Model {
                                        position: Qt.vector3d(0, -boxInstance.rh/2, 0); scale: Qt.vector3d(boxInstance.rw/100, 0.01, boxInstance.rd/100)
                                        source: "#Cube"; materials: [ PrincipledMaterial { baseColor: getActualColor(cfg ? cfg.frame_color : frameColorStr); lighting: PrincipledMaterial.NoLighting } ]
                                    }
                                }

                                Node {
                                    id: hingePivot3D
                                    readonly property string side: (root.isMerged && cfg) ? (cfg.door_side || "None") : hingeSide.cb.currentText
                                    readonly property bool isLeftHinge: side === "Left"
                                    visible: side !== "None"

                                    x: isLeftHinge ? -boxInstance.rw/2 : boxInstance.rw/2
                                    z: boxInstance.rd/2

                                    // --- THE FIX: Create a local property that we update manually ---
                                    property bool doorIsOpen: (root.isMerged && wardrobeManager) ? wardrobeManager.is_door_open(boxIdx) : root.doorOpen

                                    // Force re-check when manager emits dataChanged
                                    Connections {
                                        target: wardrobeManager
                                        function onDataChanged() {
                                            if (root.isMerged) {
                                                // This line forces the door to check the new True/False state from Python
                                                hingePivot3D.doorIsOpen = wardrobeManager.is_door_open(boxInstance.boxIdx)
                                            }
                                        }
                                    }

                                    // Use our new property for the rotation
                                    eulerRotation.y: doorIsOpen ? (isLeftHinge ? -120 : 120) : 0
                                    Behavior on eulerRotation.y { NumberAnimation { duration: 400 } }
                                    Model {
                                        id: doorModel3D
                                        pickable: true
                                        x: parent.isLeftHinge ? boxInstance.rw/2 : -boxInstance.rw/2
                                        scale: Qt.vector3d(boxInstance.rw/100, boxInstance.rh/100, 0.02)
                                        source: "#Cube"
                                        materials: [ PrincipledMaterial {
                                            baseColor: getActualColor(cfg ? cfg.door_color : doorColorStr)
                                            lighting: PrincipledMaterial.NoLighting
                                        } ]

                                        Model {
                                            id: knob3D
                                            source: "#Sphere"
                                            readonly property real dF: (((cfg ? cfg.w : wBox.value)/600 + (cfg ? cfg.h : hBox.value)/1800)/2) * 0.25
                                            scale: Qt.vector3d(dF / (boxInstance.rw/100), dF / (boxInstance.rh/100), dF / 0.02)
                                            position: Qt.vector3d(hingePivot3D.isLeftHinge ? (50 - 10) : (-50 + 10), 0, 50 + 10)
                                            materials: [ PrincipledMaterial { baseColor: "gold"; lighting: PrincipledMaterial.NoLighting } ]
                                        }
                                    }
                                }
                            }
                        }
                    }

                    PerspectiveCamera {
                        id: mainCam
                        z: (root.isMerged ? 1500 : 800) / environment.userScale
                        clipFar: 5000; clipNear: 1
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    property point lastPos

                    onWheel: (wheel) => {
                        var zoomIn = wheel.angleDelta.y > 0;
                        var factor = zoomIn ? 1.1 : 0.9;
                        environment.userScale = Math.min(Math.max(environment.userScale * factor, 0.1), 10.0);
                        mainCanvas.requestPaint();
                    }

                    onPressed: (m) => lastPos = Qt.point(m.x, m.y)
                    onPositionChanged: (m) => {
                        if (root.is3D) {
                            let diff = Qt.point(m.x - lastPos.x, m.y - lastPos.y)
                            sceneRoot.eulerRotation.y += diff.x * 0.5
                            sceneRoot.eulerRotation.x += diff.y * 0.5
                            lastPos = Qt.point(m.x, m.y)
                        }
                    }

                    onClicked: (mouse) => {
                    if (root.is3D) {
                        var result = view3D.pick(mouse.x, mouse.y);
                        if (result.objectHit) {
                            var p = result.objectHit;
                            var foundIndex = -1;
                            // Loop upwards through the parents until we find the Node that has boxIdx
                            while (p) {
                                if (p.boxIdx !== undefined) {
                                    foundIndex = p.boxIdx;
                                    break;
                                }
                                p = p.parent;
                            }

                            if (foundIndex !== -1) {
                                if (root.isMerged && wardrobeManager) {
                                    wardrobeManager.toggle_door(foundIndex);
                                    // Force the Canvas to update if needed
                                    mainCanvas.requestPaint();
                                } else {
                                    root.doorOpen = !root.doorOpen;
                                }
                            }
                        }
                    } else {
                        root.doorOpen = !root.doorOpen;
                    }
                }
                }

                Rectangle {
                    id: doorElement
                    x: (parent.width - (wBox.value * environment.finalScl)) / 2
                    y: (parent.height - (hBox.value * environment.finalScl)) / 2
                    width: wBox.value * environment.finalScl; height: hBox.value * environment.finalScl
                    color: getActualColor(doorColorStr); border.color: "black"
                    visible: root.viewMode === "Front" && hingeSide.cb.currentText !== "None"
                    transform: Scale {
                        origin.x: (hingeSide.cb.currentText === "Left") ? 0 : doorElement.width
                        xScale: doorOpen ? -1.0 : 1.0
                        Behavior on xScale { NumberAnimation { duration: 450 } }
                    }
                    Rectangle {
                        width: Math.max(4, parent.width * 0.04); height: width; radius: width/2
                        color: "gold"; border.color: "black"
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: (hingeSide.cb.currentText === "Left") ? parent.right : undefined
                        anchors.left: (hingeSide.cb.currentText === "Right") ? parent.left : undefined
                        anchors.margins: parent.width * 0.08
                    }
                }
            }
        }
    }
}