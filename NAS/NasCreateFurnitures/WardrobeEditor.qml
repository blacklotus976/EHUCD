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


            // Sync the Bind Dropdown
            if (cfg.bind_to === -1 || cfg.bind_to === undefined) {
                bindDrop.cb.currentIndex = 0; // "None"
            } else {
                let displayTarget = "Box " + (cfg.bind_to + 1);
                bindDrop.cb.currentIndex = bindDrop.cb.find(displayTarget);
            }
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
    property int hoveredIdx: -1 // -1 means no box is hovered
    readonly property real globalWidth: wardrobeManager ? wardrobeManager.get_total_width() : 0
    readonly property real globalHeight: wardrobeManager ? wardrobeManager.get_max_height() : 0
    // readonly property real globalDepth: wardrobeManager ? wardrobeManager.get_max_depth() : 0

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

    function getBindModel() {
        let list = ["None"];
        if (!wardrobeManager) return list;

        let count = wardrobeManager.tabCount;
        let current = bar.currentIndex;

        for (let i = 0; i < count; i++) {
            if (i !== current) {
                list.push("Box " + (i + 1));
            }
        }
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



        // We use a plain Item as a "wrapper" to keep the 'bar' ID alive
        Item {
            id: bar
            Layout.fillWidth: true
            Layout.preferredHeight: 400
            property int currentIndex: wardrobeManager ? wardrobeManager.activeIndex : 0

            // --- LOGIC HELPERS ---
            function getChildrenOf(parentIdx) {
                let kids = [];
                if (!wardrobeManager) return kids;
                let count = wardrobeManager.tabCount;
                for (let i = 0; i < count; i++) {
                    let cfg = wardrobeManager.get_config_at(i);
                    if (cfg && Number(cfg.bind_to) === Number(parentIdx)) kids.push(i);
                }
                return kids;
            }

            function getX(idx) {
                if (!wardrobeManager || idx < 0 || idx >= wardrobeManager.tabCount) return 0;
                let cfg = wardrobeManager.get_config_at(idx);
                if (!cfg) return 0;

                let bTo = Number(cfg.bind_to);

                // --- ROOT NODES (The bottom row) ---
                if (bTo === -1) {
                    // Find which "Root" index this is (ignoring non-root nodes)
                    let rootCount = 0;
                    let myRootIndex = 0;
                    for (let i = 0; i < wardrobeManager.tabCount; i++) {
                        let c = wardrobeManager.get_config_at(i);
                        if (c && Number(c.bind_to) === -1) {
                            if (i === idx) myRootIndex = rootCount;
                            rootCount++;
                        }
                    }
                    // Space roots out by a fixed 220px
                    return 100 + (myRootIndex * 220);
                }

                // --- CHILD NODES ---
                let parentX = getX(bTo);
                let siblings = getChildrenOf(bTo);

                // If it's an only child, put it directly above parent
                if (siblings.length <= 1) return parentX;

                // Fixed gap between siblings (70px)
                let gap = 70;
                let myIndexInSiblings = siblings.indexOf(idx);

                // Calculate total width of the sibling group
                let totalWidth = (siblings.length - 1) * gap;

                // Center the siblings relative to parentX
                return parentX - (totalWidth / 2) + (myIndexInSiblings * gap);
            }

            function getY(idx) {
                if (!wardrobeManager || idx < 0 || idx >= wardrobeManager.tabCount) return 0;
                let depth = 0;
                let curr = wardrobeManager.get_config_at(idx);
                let safety = 0;
                while (curr && Number(curr.bind_to) !== -1 && safety < 10) {
                    depth++;
                    curr = wardrobeManager.get_config_at(Number(curr.bind_to));
                    safety++;
                }
                return 340 - (depth * 80);
            }

            // --- UI CONTAINER ---
            // --- UI CONTAINER ---
    Rectangle {
        id: treeContainer
        anchors.fill: parent
        color: "#1e272e"; radius: 10; clip: true; border.color: "#3d3d3d"

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 2

            // This provides a massive infinite-feeling surface
            contentWidth: 5000
            contentHeight: 5000

            // We start scrolled toward the bottom-left because your tree starts
            // at Y=340 and grows UP. This gives you ~4600px of "Up" growth space.
            contentX: 0
            contentY: 4200

            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                width: 12; active: true
                contentItem: Rectangle { color: "#00d2d3"; radius: 6 }
            }
            ScrollBar.horizontal: ScrollBar {
                height: 12; active: true
                contentItem: Rectangle { color: "#00d2d3"; radius: 6 }
            }

            // --- SCROLLABLE CONTENT ---
            Item {
                id: treeContent
                width: flick.contentWidth
                height: flick.contentHeight

                // We add a large constant to Y so your tree lives in the "bottom"
                // area of the 5000px canvas and can grow toward 0.
                readonly property real shiftY: 4200

                Canvas {
                    id: treeCanvas
                    anchors.fill: parent
                    enabled: false

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = "#00d2d3"; ctx.lineWidth = 2;
                        if (!wardrobeManager) return;
                        for (var i = 0; i < wardrobeManager.tabCount; i++) {
                            let cfg = wardrobeManager.get_config_at(i);
                            let bTo = cfg ? Number(cfg.bind_to) : -1;
                            if (bTo !== -1) {
                                ctx.beginPath();
                                // Logic preserved: we just add shiftY to the visual output
                                ctx.moveTo(bar.getX(i) + 25, bar.getY(i) + 25 + treeContent.shiftY);
                                ctx.lineTo(bar.getX(bTo) + 25, bar.getY(bTo) + 25 + treeContent.shiftY);
                                ctx.stroke();
                            }
                        }
                    }
                }

                Repeater {
                    model: wardrobeManager ? wardrobeManager.tabCount : 0
                    delegate: Rectangle {
                        // Position logic preserved: shiftY added for visual workspace
                        x: bar.getX(index)
                        y: bar.getY(index) + treeContent.shiftY

                        width: 50; height: 50; radius: 25
                        color: bar.currentIndex === index ? "#00d2d3" : "#f1f2f6"
                        border.color: "white"; border.width: bar.currentIndex === index ? 3 : 1; z: 10

                        Text {
                            anchors.centerIn: parent
                            text: (index + 1)
                            font.bold: true; color: bar.currentIndex === index ? "white" : "#2f3542"
                        }

                        MouseArea {
                            anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                wardrobeManager.setActiveIndex(index);
                                root.refreshUI();
                                if (mouse.button === Qt.RightButton) nodeMenu.popup();
                            }
                        }

                        // --- YOUR ORIGINAL MENU (EXACTLY AS IS) ---
                        Menu {
                            id: nodeMenu
                            MenuItem {
                                text: "Add Child (Auto-Bind)"
                                onTriggered: {
                                    let pId = index;
                                    let mgr = wardrobeManager;
                                    let uiRoot = root;
                                    mgr.addBox();
                                    Qt.callLater(function() {
                                        if (mgr && uiRoot) {
                                            let newIdx = mgr.tabCount - 1;
                                            mgr.setActiveIndex(newIdx);
                                            mgr.update_setting("bind_to", pId.toString());
                                            uiRoot.refreshUI();
                                            treeCanvas.requestPaint();
                                        }
                                    });
                                }
                            }
                            MenuItem {
                                text: "Add Sibling"
                                onTriggered: {
                                    let mgr = wardrobeManager;
                                    let uiRoot = root;
                                    let myCfg = mgr.get_config_at(index);
                                    let pId = Number(myCfg.bind_to);
                                    mgr.addBox();
                                    Qt.callLater(function() {
                                        if (mgr && uiRoot) {
                                            let newIdx = mgr.tabCount - 1;
                                            mgr.setActiveIndex(newIdx);
                                            mgr.update_setting("bind_to", pId.toString());
                                            uiRoot.refreshUI();
                                            treeCanvas.requestPaint();
                                        }
                                    });
                                }
                            }
                            MenuSeparator { visible: wardrobeManager && wardrobeManager.tabCount > 1 }
                            MenuItem {
                                text: "Delete Node (Adopt Children)"
                                visible: wardrobeManager && wardrobeManager.tabCount > 1
                                onTriggered: {
                                    let targetIdx = index;
                                    let mgr = wardrobeManager;
                                    let uiRoot = root;
                                    let myCfg = mgr.get_config_at(targetIdx);
                                    let myParentId = Number(myCfg.bind_to);
                                    let myChildren = bar.getChildrenOf(targetIdx);
                                    for (let i = 0; i < myChildren.length; i++) {
                                        let childIdx = myChildren[i];
                                        mgr.setActiveIndex(childIdx);
                                        mgr.update_setting("bind_to", myParentId.toString());
                                    }
                                    mgr.removeBox(targetIdx);
                                    Qt.callLater(function() {
                                        if (mgr && uiRoot) {
                                            let safeIdx = Math.max(0, targetIdx - 1);
                                            mgr.setActiveIndex(safeIdx);
                                            uiRoot.refreshUI();
                                            treeCanvas.requestPaint();
                                        }
                                    });
                                }
                            }
                        }
                    }
                }
            }
        }

        Connections {
            target: wardrobeManager
            function onDataChanged() { treeCanvas.requestPaint(); }
        }
    }
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

                // NEW: Vertical Binding Dropdown
                ConfigDrop {
                    id: bindDrop
                    title: "Bind Vertically To"
                    settingKey: "bind_to"
                    // Dynamically fetch the model whenever tabs change
                    modelData: root.getBindModel()

                    // We override the onActivated because we need to save the index, not just the text
                    cb.onActivated: {
                        let selectedText = cb.currentText;
                        let targetIdx = -1; // Default for "None"

                        if (selectedText !== "None") {
                            // Extract the number from "Box X" and convert to 0-based index
                            targetIdx = parseInt(selectedText.replace("Box ", "")) - 1;
                        }

                        if (wardrobeManager) {
                            wardrobeManager.update_setting("bind_to", targetIdx);
                        }
                    }
                }
                Column {
                    spacing: 5
                    Label { text: "Back Contrast"; font.bold: true; color: "#555" }
                    Switch { checked: root.contrastBackFrame; onToggled: root.contrastBackFrame = checked }
                }
                Row {
                    Layout.alignment: Qt.AlignBottom; spacing: 10
                    // We removed the 'value' property binding to prevent the tabs from "leaking" values
                    CompactInput { id: wBox; label: "W"; sKey: "width" }
                    CompactInput { id: hBox; label: "H"; sKey: "height"; value:1800 }
                    CompactInput { id: dBox; label: "D"; sKey: "depth" }
                }
                // Place this in your parameters column
                // --- FIXED WIDTH OFFSET SECTION ---
                RowLayout {
                    Layout.columnSpan: 2
                    spacing: 10

                    Label {
                        text: "Width Offset (mm):"
                        font.bold: true
                        color: "#555"
                    }

                    SpinBox {
                        id: offsetSpin
                        from: -2000; to: 2000
                        editable: true
                        stepSize: 10

                        // Use a property to track the backend value without "Hard Binding"
                        // This prevents the "reset to 0" flicker when hitting enter.
                        property int backendValue: {
                            if (!wardrobeManager) return 0;
                            let cfg = wardrobeManager.get_config_at(bar.currentIndex);
                            return (cfg && cfg.width_offset !== undefined) ? cfg.width_offset : 0;
                        }

                        // Update the visual position when the backend or tab changes
                        onBackendValueChanged: value = backendValue

                        // STYLING: Matching your other parameters
                        contentItem: TextInput {
                            z: 2
                            text: offsetSpin.textFromValue(offsetSpin.value, offsetSpin.locale)
                            font.pixelSize: 14
                            color: "#2f3542" // Dark grey text (visible)
                            selectionColor: "#3498db"
                            selectedTextColor: "white"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !offsetSpin.editable
                            validator: offsetSpin.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly

                            // THE LOGIC FIX: Commit data only when explicitly finished
                            onEditingFinished: {
                                let val = parseInt(text);
                                if (!isNaN(val)) {
                                    if (wardrobeManager) {
                                        wardrobeManager.update_setting("width_offset", val.toString());
                                    }
                                }
                            }
                        }

                        // Handle the + / - button clicks
                        onValueModified: {
                            if (wardrobeManager) {
                                wardrobeManager.update_setting("width_offset", value.toString());
                            }
                        }

                        background: Rectangle {
                            implicitWidth: 100
                            implicitHeight: 35
                            border.color: "#dce1e8"
                            radius: 4
                            color: "white"
                        }
                    }

                    Button {
                        text: "Reset"
                        // Using a flat, clean style to match the panel
                        onClicked: {
                            if (wardrobeManager) {
                                wardrobeManager.update_setting("width_offset", "0");
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: environment
            Layout.fillWidth: true; Layout.fillHeight: true; color: "#2c3e50"; radius: 10; clip: true
            property real userScale: 1.0
            readonly property real finalScl: ((height * 0.4) / 2000) * userScale
            property bool apply2DScroll: false

            // 1. DEFINE THE PROPERTIES PROPERLY
            property real worldXOffset: 0
            property real worldYOffset: 0

            // property real userScale: 1.0
            // readonly property real finalScl: ((height * 0.4) / 2000) * userScale

            // --- SCROLLBARS (Visibility limited to 3D Merged View) ---

            // ScrollBar {
            //     id: vScroll
            //     anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
            //     width: 15; z: 50; active: true
            //     visible: root.is3D && root.isMerged
            //
            //     position: 0.5
            //     onPositionChanged: {
            //         // Get the actual height of the building in 3D units
            //         let totalHeight3D = (wardrobeManager ? wardrobeManager.get_max_height() * 0.2 : 1000);
            //
            //         // Limit the scroll so we can only go as high/low as the building exists
            //         // We use totalHeight3D as the maximum offset
            //         environment.worldYOffset = (0.5 - position) * (totalHeight3D * 2);
            //     }
            // }
            // ScrollBar {
            //     id: hScroll
            //     anchors.left: parent.left; anchors.right: vScroll.left; anchors.bottom: parent.bottom
            //     height: 15; z: 50; orientation: Qt.Horizontal; active: true
            //     visible: root.is3D && root.isMerged
            //
            //     position: 0.5
            //     onPositionChanged: {
            //         // Same logic for width
            //         let totalWidth3D = (wardrobeManager ? wardrobeManager.get_total_width() * 0.2 : 1000);
            //         environment.worldXOffset = (0.5 - position) * (totalWidth3D * 2);
            //     }
            // }
            // --- VERTICAL SCROLLBAR ---
            ScrollBar {
                id: vScroll3D
                anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                width: 12; z: 100
                visible: root.is3D && root.isMerged && environment.apply2DScroll

                size: 0.15
                position: 0.5

                // THE FIX: Disable wheel interaction so it doesn't fight the Zoom
                interactive: true   // Allows dragging the handle
                wheelEnabled: false // Prevents the wheel from moving the scrollbar

                contentItem: Rectangle { color: "#3498db"; radius: 6 }

                onPositionChanged: {
                    if (pressed) {
                        environment.worldYOffset = (0.5 - position) * 10000;
                    }
                }
            }

            // --- HORIZONTAL SCROLLBAR ---
            ScrollBar {
                id: hScroll3D
                anchors.left: parent.left; anchors.right: vScroll3D.left; anchors.bottom: parent.bottom
                height: 12; z: 100; orientation: Qt.Horizontal
                visible: root.is3D && root.isMerged && environment.apply2DScroll

                size: 0.15
                position: 0.5

                // THE FIX: Disable wheel interaction
                interactive: true
                wheelEnabled: false

                contentItem: Rectangle { color: "#3498db"; radius: 6 }

                onPositionChanged: {
                    if (pressed) {
                        environment.worldXOffset = (position - 0.5) * 10000;
                    }
                }
            }




            ComboBox {
                id: modeSelect
                anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 15; z: 10
                model: ["Front", "Depth 2D", "3D View"]
                onActivated: {
                    root.viewMode = currentText; // This changes the 'is3D' and 'isDepth2D' properties
                    doorOpen = false;
                    environment.worldXOffset = 0; environment.worldYOffset = 0;
            vScroll3D.position = 0.5; hScroll3D.position = 0.5;
                    mainCanvas.requestPaint();
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


                Button {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.leftMargin: 130 // Offset so it doesn't overlap the Merged button
                    anchors.topMargin: 15
                    z: 20
                    visible: root.is3D && root.isMerged

                    text: environment.apply2DScroll ? "Scroll: ON" : "Scroll: OFF"

                    // Aesthetic: change color based on state
                    background: Rectangle {
                        implicitWidth: 100
                        implicitHeight: 40
                        color: environment.apply2DScroll ? "#00d2d3" : "#34495e"
                        radius: 4
                    }

                    onClicked: {
                        environment.apply2DScroll = !environment.apply2DScroll
                        if (!environment.apply2DScroll) {
                            // Reset positions when turning off
                            environment.worldXOffset = 0
                            environment.worldYOffset = 0
                            vScroll3D.position = 0.5
                            hScroll3D.position = 0.5
                        }
                    }
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





                View3D {
                    id: view3D
                    anchors.fill: parent; visible: root.is3D
                    environment: SceneEnvironment { clearColor: "#2c3e50"; backgroundMode: SceneEnvironment.Color }

                    Node {
                        id: sceneRoot
                        // x: environment.worldXOffset
                        // y: environment.worldYOffset
                        x: environment.apply2DScroll ? environment.worldXOffset : 0
                        // y: environment.apply2DScroll ? (environment.worldYOffset - 300) : -300
                        // Y FIX:
                        // If scrolling is ON: Use the manual offset.
                        // If scrolling is OFF: We shift the whole thing down by half of the max height
                        // so that the wardrobe grows from the CENTER of the screen, not the bottom.
                        y: {
                            if (environment.apply2DScroll) {
                                return environment.worldYOffset - 300;
                            } else {
                                // This calculates half the height of your total wardrobe build
                                let totalH = (wardrobeManager ? wardrobeManager.get_max_height() * 0.2 : 0);
                                return - (totalH / 2);
                            }
                        }


                        eulerRotation.y: -25; eulerRotation.x: -15

                        Repeater3D {
                            id: wardrobeRepeater
                            model: (root.isMerged && wardrobeManager) ? wardrobeManager.tabCount : 1

                            Node {
                                id: boxInstance
                                readonly property int boxIdx: root.isMerged ? index : bar.currentIndex
                                readonly property real sF: 0.2

                                // Force these to be calculated immediately
                                property var cfg: (wardrobeManager) ? wardrobeManager.get_config_at(boxIdx) : null
                                Connections {
                                    target: wardrobeManager
                                    // This is the trigger!
                                    function onDataChanged() {
                                        // Re-fetch the config for THIS specific box index
                                        boxInstance.cfg = wardrobeManager.get_config_at(boxInstance.boxIdx)

                                        // Debug to see it happening in real-time
                                        console.log("Updating Box " + boxInstance.boxIdx + " - New Color: " + boxInstance.cfg.door_color)
                                    }
                                }
                                // Use internal aliases to ensure they are available to the scope
                                readonly property real localW: (cfg && cfg.w ? cfg.w : 600) * sF
                                readonly property real localH: (cfg && cfg.h ? cfg.h : 1800) * sF
                                readonly property real localD: (cfg && cfg.d ? cfg.d : 600) * sF

                                // Now use localW, localH, localD instead of rw, rh, rd in your positions
                                // x: {
                                //     if (!root.isMerged || !wardrobeManager || !cfg) return 0;
                                //
                                //     function getFloorParentIdx(idx) {
                                //         let current = idx;
                                //         let safety = 0;
                                //         while (safety < 10) {
                                //             let c = wardrobeManager.get_config_at(current);
                                //             if (c && c.bind_to !== -1 && c.bind_to !== undefined) {
                                //                 current = c.bind_to;
                                //                 safety++;
                                //             } else {
                                //                 break;
                                //             }
                                //         }
                                //         return current;
                                //     }
                                //
                                //     let floorIdx = getFloorParentIdx(boxIdx);
                                //
                                //     let offset = 0;
                                //     let totalWidth = wardrobeManager.get_total_width();
                                //     for (let i = 0; i < floorIdx; i++) {
                                //         let c = wardrobeManager.get_config_at(i);
                                //         // Only count boxes that are actually on the floor
                                //         if (c && (c.bind_to === -1 || c.bind_to === undefined)) {
                                //             offset += c.w;
                                //         }
                                //     }
                                //     return (offset + (wardrobeManager.get_box_width(floorIdx) / 2) - (totalWidth / 2)) * sF;
                                // }
                                // Inside Repeater3D -> Node { id: boxInstance }
x: {
    if (!root.isMerged || !wardrobeManager || !cfg) return 0;

    function getFloorParentIdx(idx) {
        let current = idx;
        let safety = 0;
        while (safety < 10) {
            let c = wardrobeManager.get_config_at(current);
            if (c && c.bind_to !== -1 && c.bind_to !== undefined) {
                current = c.bind_to;
                safety++;
            } else { break; }
        }
        return current;
    }

    let floorIdx = getFloorParentIdx(boxIdx);
    let totalWidth = wardrobeManager.get_total_width();
    let offset = 0;
    for (let i = 0; i < floorIdx; i++) {
        let c = wardrobeManager.get_config_at(i);
        if (c && (c.bind_to === -1 || c.bind_to === undefined)) {
            offset += c.w;
        }
    }

    // --- THE FIX: GLOBAL CENTER + LOCAL OFFSET ---
    let columnCenterX = (offset + (wardrobeManager.get_box_width(floorIdx) / 2) - (totalWidth / 2)) * sF;

    // We add the width_offset here. Multiply by sF (0.2) to match 3D scale.
    let nudge = (cfg.width_offset ? cfg.width_offset : 0) * sF;

    return columnCenterX + nudge;
}

                                y: {
                                    let halfH = localH / 2;
                                    if (!root.isMerged || !wardrobeManager || !cfg) return halfH;

                                    let currentBind = cfg.bind_to;
                                    let accumulatedHeight = 0;
                                    let safetyCounter = 0;

                                    // Loop upwards through the chain
                                    while (currentBind !== -1 && currentBind !== undefined && safetyCounter < 10) {
                                        let parentCfg = wardrobeManager.get_config_at(currentBind);
                                        if (parentCfg) {
                                            accumulatedHeight += (parentCfg.h * sF);
                                            currentBind = parentCfg.bind_to; // Move to the parent's parent
                                            safetyCounter++;
                                        } else {
                                            break;
                                        }
                                    }
                                    return accumulatedHeight + halfH;
                                }

                                z: localD / 2 // Use the local variable

                                Node {
                                    id: wardrobeShell
                                    Model {
                                        id: backPanel
                                        pickable: true
                                        // WAS: boxInstance.rd/2 -> IS: boxInstance.localD/2
                                        position: Qt.vector3d(0, 0, -boxInstance.localD/2)
                                        scale: Qt.vector3d(boxInstance.localW/100, boxInstance.localH/100, 0.01)
                                        source: "#Cube"
                                        materials: [ PrincipledMaterial {
                                            baseColor: root.contrastBackFrame ? "grey" : getActualColor(cfg ? cfg.frame_color : frameColorStr)
                                            lighting: PrincipledMaterial.NoLighting
                                        } ]
                                        // visible: root.hoveredIdx === boxInstance.boxIdx && root.isMerged
                                        // materials: [
                                        //     PrincipledMaterial {
                                        //         baseColor: "transparent"
                                        //         opacity: 0.3
                                        //         lighting: PrincipledMaterial.NoLighting
                                        //     }
                                        // ]
                                    }
                                    // SIDES
                                    Model {
                                        position: Qt.vector3d(-boxInstance.localW/2, 0, 0)
                                        scale: Qt.vector3d(0.01, boxInstance.localH/100, boxInstance.localD/100)
                                        source: "#Cube"; materials: [ PrincipledMaterial { baseColor: getActualColor(cfg ? cfg.frame_color : frameColorStr); lighting: PrincipledMaterial.NoLighting } ]
                                    }
                                    Model {
                                        // FIXED THIS ONE (Was using rh/rd)
                                        position: Qt.vector3d(boxInstance.localW/2, 0, 0)
                                        scale: Qt.vector3d(0.01, boxInstance.localH/100, boxInstance.localD/100)
                                        source: "#Cube"; materials: [ PrincipledMaterial { baseColor: getActualColor(cfg ? cfg.frame_color : frameColorStr); lighting: PrincipledMaterial.NoLighting } ]
                                    }
                                    // TOP & BOTTOM
                                    Model {
                                        position: Qt.vector3d(0, boxInstance.localH/2, 0)
                                        scale: Qt.vector3d(boxInstance.localW/100, 0.01, boxInstance.localD/100)
                                        source: "#Cube"; materials: [ PrincipledMaterial { baseColor: getActualColor(cfg ? cfg.frame_color : frameColorStr); lighting: PrincipledMaterial.NoLighting } ]
                                    }
                                    Model {
                                        position: Qt.vector3d(0, -boxInstance.localH/2, 0)
                                        scale: Qt.vector3d(boxInstance.localW/100, 0.01, boxInstance.localD/100)
                                        source: "#Cube"; materials: [ PrincipledMaterial { baseColor: getActualColor(cfg ? cfg.frame_color : frameColorStr); lighting: PrincipledMaterial.NoLighting } ]
                                    }
                                }

                                Node {
                                    id: hingePivot3D
                                    readonly property string side: (root.isMerged && cfg) ? (cfg.door_side || "None") : hingeSide.cb.currentText
                                    readonly property bool isLeftHinge: side === "Left"
                                    visible: side !== "None"

                                    x: isLeftHinge ? -boxInstance.localW/2 : boxInstance.localW/2
                                    z: boxInstance.localD/2

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
                                        x: parent.isLeftHinge ? boxInstance.localW/2 : -boxInstance.localW/2
                                        scale: Qt.vector3d(boxInstance.localW/100, boxInstance.localH/100, 0.02)
                                        source: "#Cube"
                                        materials: [ PrincipledMaterial {
                                            baseColor: getActualColor(cfg ? cfg.door_color : doorColorStr)
                                            lighting: PrincipledMaterial.NoLighting
                                        } ]

                                        Model {
                                            id: knob3D
                                            source: "#Sphere"
                                            readonly property real dF: (((cfg ? cfg.w : wBox.value)/600 + (cfg ? cfg.h : hBox.value)/1800)/2) * 0.25
                                            scale: Qt.vector3d(dF / (boxInstance.localW/100), dF / (boxInstance.localH/100), dF / 0.02)
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
                        z: 1500 / environment.userScale
                        // y: 150 // Lifts the camera's "eye level" slightly
                        clipFar: 10000; clipNear: 1
                    }

                    Rectangle {
                        id: dimOverlay
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: 20
                        width: dimText.width + 30
                        height: 45
                        color: "#AA000000" // Semi-transparent black
                        radius: 8
                        border.color: "#3498db"
                        border.width: root.hoveredIdx !== -1 ? 2 : 0 // Highlight border on hover

                        Text {
                            id: dimText
                            anchors.centerIn: parent
                            color: "white"
                            font.pixelSize: 14
                            font.bold: true

                            // THE LOGIC GATE
                            text: {
                                if (!root.isMerged) {
                                    // Single View: Just show active tab dims
                                    return "Dimensions: " + wBox.value + "W x " + hBox.value + "H x " + dBox.value + "D";
                                } else {
                                    if (root.hoveredIdx === -1) {
                                        // Global view (Sum of all widths, Max height of stacks)
                                        return "OVERALL: " + wardrobeManager.get_total_width() + "W x " +
                                               wardrobeManager.get_max_height() + "H x " +
                                               wardrobeManager.get_max_depth() + "D";
                                    } else {
                                        // Specific Box Hovered
                                        let hCfg = wardrobeManager.get_config_at(root.hoveredIdx);
                                        return "Box " + (root.hoveredIdx + 1) + ": " +
                                               hCfg.w + "W x " + hCfg.h + "H x " + hCfg.d + "D";
                                    }
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    property point lastPos
                    // 1. Enable hover tracking
                    hoverEnabled: true

                    onWheel: (wheel) => {
                        var zoomIn = wheel.angleDelta.y > 0;
                        var factor = zoomIn ? 1.1 : 0.9;
                        environment.userScale = Math.min(Math.max(environment.userScale * factor, 0.1), 10.0);
                        mainCanvas.requestPaint();
                    }

                    onPressed: (m) => lastPos = Qt.point(m.x, m.y)

                    onPositionChanged: (m) => {
                        if (root.is3D) {
                            // --- Part A: Existing Rotation Logic (If mouse is pressed) ---
                            if (pressed) {
                                let diff = Qt.point(m.x - lastPos.x, m.y - lastPos.y)
                                sceneRoot.eulerRotation.y += diff.x * 0.5
                                sceneRoot.eulerRotation.x += diff.y * 0.5
                                lastPos = Qt.point(m.x, m.y)
                            }

                            // --- Part B: New Hover/Picking Logic ---
                            var result = view3D.pick(m.x, m.y);
                            if (result.objectHit) {
                                var p = result.objectHit;
                                var foundHoverIndex = -1;
                                while (p) {
                                    if (p.boxIdx !== undefined) {
                                        foundHoverIndex = p.boxIdx;
                                        break;
                                    }
                                    p = p.parent;
                                }
                                root.hoveredIdx = foundHoverIndex;
                            } else {
                                root.hoveredIdx = -1; // Reset if hovering over empty space
                            }
                        }
                    }

                    onClicked: (mouse) => {
                        if (root.is3D) {
                            var result = view3D.pick(mouse.x, mouse.y);
                            if (result.objectHit) {
                                var p = result.objectHit;
                                var foundIndex = -1;
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

                    // Reset hover when mouse leaves the area
                    onExited: root.hoveredIdx = -1
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