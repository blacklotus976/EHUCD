import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: root
    width: 1100; height: 950; visible: true; title: "Wardrobe Architect v2.1.0"
    color: "#f0f2f5"

    property bool isDepthView: false
    property bool doorOpen: false

    function getValidHinges() {
        if (!wardrobeManager) return ["Left", "Right", "None"];
        let list = ["Left", "Right", "None"];
        if (wardrobeManager.get_neighbor_side(-1) === "Right") list = list.filter(item => item !== "Left");
        if (wardrobeManager.get_neighbor_side(1) === "Left") list = list.filter(item => item !== "Right");
        return list;
    }

    Connections {
        target: wardrobeManager
        function onDataChanged() {
            let cfg = wardrobeManager.get_full_config();
            wBox.value = cfg.w; hBox.value = cfg.h; dBox.value = cfg.d;
            let valid = getValidHinges();
            hingeSide.modelData = valid;
            if (valid.indexOf(cfg.side) === -1) { wardrobeManager.update_setting("door_side", "None"); }
            mainCanvas.requestPaint();
        }
    }

    component ConfigDrop : Column {
        property string title: ""; property var modelData; property string settingKey
        property alias cb: combo
        spacing: 5
        Label { text: title; font.bold: true; color: "#555" }
        ComboBox {
            id: combo; width: 160; model: parent.modelData
            onActivated: { wardrobeManager.update_setting(settingKey, currentText); mainCanvas.requestPaint() }
        }
    }

    component CompactInput : Column {
        property string label: ""; property real value: 600.0; property string sKey
        spacing: 5
        Label { text: label; font.bold: true; color: "#555" }
        TextField {
            width: 100; text: parent.value.toString(); placeholderText: "mm"; selectByMouse: true
            validator: DoubleValidator { bottom: 100; top: 3000 }
            onEditingFinished: { parent.value = parseFloat(text); wardrobeManager.update_setting(sKey, text); mainCanvas.requestPaint() }
        }
    }

    readonly property string doorColorStr: (wardrobeManager && wardrobeManager.doorColor) ? wardrobeManager.doorColor : "white"

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 20; spacing: 10

        RowLayout {
            Layout.fillWidth: true; spacing: 5
            TabBar {
                id: bar; Layout.fillWidth: true
                currentIndex: wardrobeManager ? wardrobeManager.activeIndex : 0
                Repeater {
                    model: wardrobeManager ? wardrobeManager.tabCount : 1
                    TabButton {
                        width: 160
                        contentItem: RowLayout {
                            spacing: 0
                            ToolButton { text: "‹"; visible: index > 0; onClicked: wardrobeManager.moveBox(index, index - 1) }
                            Text { text: "Box " + (index + 1); horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true; font.bold: bar.currentIndex === index }
                            ToolButton { text: "›"; visible: index < (wardrobeManager.tabCount - 1); onClicked: wardrobeManager.moveBox(index, index + 1) }
                            ToolButton { text: "×"; visible: index > 0; onClicked: wardrobeManager.removeBox(index) }
                        }
                        onClicked: { wardrobeManager.setActiveIndex(index); doorOpen = false }
                    }
                }
            }
            Button { text: "+ Add"; onClicked: wardrobeManager.addBox() }
        }

        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 140; color: "white"; radius: 10; border.color: "#dce1e8"
            GridLayout {
                anchors.fill: parent; anchors.margins: 15; columns: 4; rowSpacing: 10
                ConfigDrop { title: "Door Color"; modelData: ["White", "Grey", "Oak", "Black"]; settingKey: "door_color" }
                ConfigDrop { title: "Frame Color"; modelData: ["Grey", "White", "Black", "Oak"]; settingKey: "frame_color" }
                ConfigDrop { id: hingeSide; title: "Hinge Side"; modelData: ["Left", "Right", "None"]; settingKey: "door_side" }
                Row {
                    Layout.alignment: Qt.AlignBottom; spacing: 10
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

            MouseArea {
                anchors.fill: parent
                onWheel: (wheel) => {
                    if (wheel.angleDelta.y > 0) environment.userScale = Math.min(environment.userScale + 0.1, 2.0)
                    else environment.userScale = Math.max(environment.userScale - 0.1, 0.25)
                }
            }

            Button {
                text: isDepthView ? "Front View" : "Depth View"
                anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 15; z: 10
                onClicked: { isDepthView = !isDepthView; doorOpen = false; mainCanvas.requestPaint() }
            }

            Item {
                id: viewport
                anchors.centerIn: parent
                width: (wBox.value * environment.finalScl * 2) + 200
                height: (hBox.value * environment.finalScl) + 200

                Canvas {
                    id: mainCanvas; anchors.fill: parent
                    function drawDim(ctx, x1, y1, x2, y2, label) {
                        var headlen = 8 * environment.userScale;
                        var angle = Math.atan2(y2-y1, x2-x1);
                        ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2);
                        ctx.moveTo(x1, y1); ctx.lineTo(x1 + headlen * Math.cos(angle + Math.PI/6), y1 + headlen * Math.sin(angle + Math.PI/6));
                        ctx.moveTo(x1, y1); ctx.lineTo(x1 + headlen * Math.cos(angle - Math.PI/6), y1 + headlen * Math.sin(angle - Math.PI/6));
                        ctx.moveTo(x2, y2); ctx.lineTo(x2 - headlen * Math.cos(angle - Math.PI/6), y2 - headlen * Math.sin(angle - Math.PI/6));
                        ctx.moveTo(x2, y2); ctx.lineTo(x2 - headlen * Math.cos(angle + Math.PI/6), y2 - headlen * Math.sin(angle + Math.PI/6));
                        ctx.stroke();
                        ctx.save(); ctx.translate((x1 + x2) / 2, (y1 + y2) / 2);
                        if (Math.abs(y2 - y1) > Math.abs(x2 - x1)) { ctx.rotate(-Math.PI / 2); ctx.fillText(label, 0, -10); }
                        else { ctx.fillText(label, 0, 18); }
                        ctx.restore();
                    }

                    onPaint: {
                        var ctx = getContext("2d"); ctx.reset();
                        var scl = environment.finalScl;
                        var rw = wBox.value * scl; var rh = hBox.value * scl; var rs = dBox.value * 0.4 * scl;
                        var ox = (parent.width - rw) / 2 + (rs / 2);
                        var oy = (parent.height - rh) / 2 + (rs / 2);
                        ctx.font = "bold " + Math.max(10, 14 * environment.userScale) + "px sans-serif";
                        ctx.lineWidth = 1.5; ctx.textAlign = "center";
                        var fCol = (wardrobeManager && wardrobeManager.frameColor) ? wardrobeManager.frameColor : "grey";
                        var lineCol = (fCol.toLowerCase() === "#ffffff" || fCol.toLowerCase() === "white") ? "black" : "white";

                        if (isDepthView) {
                            var bx = ox - rs; var by = oy - rs;
                            ctx.fillStyle = fCol; ctx.fillRect(bx, by, rw, rh);
                            ctx.strokeStyle = lineCol; ctx.strokeRect(bx, by, rw, rh);
                            ctx.beginPath(); ctx.moveTo(bx, by); ctx.lineTo(ox, oy);
                            ctx.lineTo(ox, oy + rh); ctx.lineTo(bx, by + rh);
                            ctx.closePath(); ctx.fill(); ctx.stroke();
                            ctx.beginPath(); ctx.moveTo(bx, by); ctx.lineTo(ox, oy);
                            ctx.lineTo(ox + rw, oy); ctx.lineTo(bx + rw, by);
                            ctx.closePath(); ctx.fill(); ctx.stroke();
                            ctx.fillRect(ox, oy, rw, rh); ctx.strokeRect(ox, oy, rw, rh);

                            // REAPPLIED DEPTH AXES
                            ctx.strokeStyle = "#00f2ff"; ctx.fillStyle = "#00f2ff";
                            drawDim(ctx, ox, oy + rh + 40, ox + rw, oy + rh + 40, (wBox.value/10) + " cm");
                            drawDim(ctx, ox + rw + 40, oy, ox + rw + 40, oy + rh, (hBox.value/10) + " cm");
                            drawDim(ctx, bx - 30, by + rh + 30, ox - 30, oy + rh + 30, (dBox.value/10) + " cm");
                        } else {
                            var fox = (parent.width - rw) / 2; var foy = (parent.height - rh) / 2 - 20;
                            ctx.fillStyle = fCol; ctx.fillRect(fox, foy, rw, rh);
                            ctx.strokeStyle = lineCol; ctx.strokeRect(fox, foy, rw, rh);

                            // REAPPLIED FRONT AXES
                            ctx.strokeStyle = "white"; ctx.fillStyle = "white";
                            var isLeftHinge = (hingeSide.cb.currentText === "Left");
                            var xStart = doorOpen ? (isLeftHinge ? fox - rw : fox) : fox;
                            var xEnd = doorOpen ? (isLeftHinge ? fox + rw : fox + rw * 2) : fox + rw;
                            drawDim(ctx, xStart, foy + rh + 45, xEnd, foy + rh + 45, (wBox.value/10) + (doorOpen ? "*2" : "") + " cm");
                            var hAxisX = isLeftHinge ? fox + rw + 45 : fox - 45;
                            drawDim(ctx, hAxisX, foy, hAxisX, foy + rh, (hBox.value/10) + " cm");
                        }
                    }
                }

                Rectangle {
                    id: doorElement
                    x: (parent.width - (wBox.value * environment.finalScl)) / 2
                    y: (parent.height - (hBox.value * environment.finalScl)) / 2 - 20
                    width: wBox.value * environment.finalScl; height: hBox.value * environment.finalScl
                    color: doorColorStr; border.color: "black"
                    visible: !isDepthView && hingeSide.cb.currentText !== "None"
                    opacity: 0.95
                    transform: Scale {
                        origin.x: (hingeSide.cb.currentText === "Left") ? 0 : doorElement.width
                        xScale: doorOpen ? -1.0 : 1.0
                        Behavior on xScale { NumberAnimation { duration: 450 } }
                    }
                    Rectangle {
                        id: knob
                        width: Math.max(8, parent.width * 0.04); height: width; radius: width/2
                        color: "gold"; border.color: "black"
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: (hingeSide.cb.currentText === "Left") ? parent.right : undefined
                        anchors.left: (hingeSide.cb.currentText === "Right") ? parent.left : undefined
                        anchors.margins: parent.width * 0.08
                    }
                    MouseArea { anchors.fill: parent; onClicked: doorOpen = !doorOpen }
                }
            }
        }
    }
}