import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property string dayKey: ""
    signal back()
    signal saved()

    // Grid constants
    property int slotSecs: 1800        // 30 minutes per slot
    property real cellW: 14
    property real cellH: 26
    property real labelW: 108
    property real timeLabelW: 56

    // Project state: [{name, color, cells: bool[], originalSeconds}]
    property var projectStates: []
    property int numSlots: 24          // updated in loadData()

    readonly property var palette: [
        "#4a86c8", "#e07b54", "#5cb85c", "#9b59b6",
        "#e67e22", "#1abc9c", "#e74c3c", "#f39c12"
    ]

    Component.onCompleted: {
        if (dayKey !== "") loadData()
    }

    onDayKeyChanged: {
        if (dayKey !== "") loadData()
    }

    function loadData() {
        var data = backend.getDayData(dayKey)
        if (!data || data.length === 0) {
            projectStates = []
            numSlots = 24
            return
        }

        // Compute numSlots: enough for max project time + 4 buffer slots, min 24
        var maxSecs = 0
        for (var i = 0; i < data.length; i++) {
            if (data[i].seconds > maxSecs) maxSecs = data[i].seconds
        }
        var needed = Math.ceil(maxSecs / slotSecs) + 4
        numSlots = Math.max(24, needed)

        var states = []
        for (var j = 0; j < data.length; j++) {
            var proj = data[j]
            var filled = Math.min(Math.round(proj.seconds / slotSecs), numSlots)
            var cells = []
            for (var k = 0; k < numSlots; k++) {
                cells.push(k < filled)
            }
            states.push({
                name: proj.project,
                color: palette[j % palette.length],
                cells: cells,
                originalSeconds: proj.seconds
            })
        }
        projectStates = states
    }

    function countFilled(cells) {
        var n = 0
        for (var i = 0; i < cells.length; i++) {
            if (cells[i]) n++
        }
        return n
    }

    function fmtSlots(n) {
        var secs = n * slotSecs
        var h = Math.floor(secs / 3600)
        var m = Math.floor((secs % 3600) / 60)
        if (h > 0 && m > 0) return h + "h " + m + "m"
        if (h > 0) return h + "h"
        if (m > 0) return m + "m"
        return "0m"
    }

    function applyDrag(projIdx, fromCell, toCell, fillVal) {
        var start = Math.min(fromCell, toCell)
        var end   = Math.max(fromCell, toCell)
        var newStates = projectStates.slice()
        var ps = newStates[projIdx]
        var newCells = ps.cells.slice()
        for (var i = start; i <= end; i++) {
            newCells[i] = fillVal
        }
        newStates[projIdx] = {
            name: ps.name,
            color: ps.color,
            cells: newCells,
            originalSeconds: ps.originalSeconds
        }
        projectStates = newStates
    }

    function saveAll() {
        for (var i = 0; i < projectStates.length; i++) {
            var ps = projectStates[i]
            var newSecs = countFilled(ps.cells) * slotSecs
            backend.updateDayProjectTime(dayKey, ps.name, newSecs)
        }
        root.saved()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Back + title
        Label {
            text: "\u2190 Back"
            font.pixelSize: 14
            color: backMa.containsMouse ? "#1f2937" : "#6b7280"
            Layout.bottomMargin: 4

            MouseArea {
                id: backMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.back()
            }
        }

        Label {
            text: dayKey !== "" ? backend.dayDetailTitle(dayKey) : ""
            font.pixelSize: 20
            font.bold: true
            color: "#1f2937"
            Layout.bottomMargin: 12
        }

        // Empty state
        Label {
            text: "No time logged for this day"
            font.pixelSize: 14
            color: "#adb5bd"
            visible: projectStates.length === 0
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 20
        }

        // Grid area
        Flickable {
            id: gridFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: labelW + numSlots * cellW + timeLabelW + 8
            contentHeight: gridCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalAndVerticalFlick
            visible: projectStates.length > 0

            ColumnLayout {
                id: gridCol
                spacing: 2

                // Header row: time labels every 2 slots (hourly)
                Row {
                    spacing: 0

                    // Spacer aligning with project label column
                    Item { width: labelW; height: 18 }

                    Repeater {
                        model: numSlots
                        Item {
                            width: cellW
                            height: 18
                            // Show hour label at every even slot boundary (index 0 = start, label at end of slot)
                            Label {
                                visible: (index + 1) % 2 === 0
                                anchors.horizontalCenter: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: ((index + 1) / 2) + "h"
                                font.pixelSize: 9
                                color: "#9ca3af"
                            }
                        }
                    }
                }

                // Project rows
                Repeater {
                    id: projectRepeater
                    model: projectStates.length

                    Item {
                        id: rowItem
                        required property int index
                        property var ps: projectStates[index] || {name: "", color: "#ccc", cells: [], originalSeconds: 0}

                        width: labelW + numSlots * cellW + timeLabelW + 8
                        height: cellH + 4

                        // Project name label (fixed left)
                        Label {
                            id: projNameLabel
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: labelW - 6
                            text: ps.name
                            font.pixelSize: 12
                            color: "#1f2937"
                            elide: Text.ElideRight
                        }

                        // Cell row
                        Row {
                            id: cellRow
                            anchors.left: parent.left
                            anchors.leftMargin: labelW
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Repeater {
                                model: numSlots
                                Rectangle {
                                    required property int index
                                    width: cellW - 1
                                    height: cellH
                                    radius: 2
                                    color: rowItem.ps.cells[index] ? rowItem.ps.color : "#e0e0e0"
                                }
                            }
                        }

                        // Drag MouseArea (sits over cell row)
                        MouseArea {
                            id: dragArea
                            anchors.left: cellRow.left
                            anchors.top: cellRow.top
                            width: numSlots * cellW
                            height: cellH
                            hoverEnabled: false
                            cursorShape: Qt.PointingHandCursor

                            property int dragStartIdx: -1
                            property bool dragFillVal: false

                            function cellAt(mx) {
                                return Math.max(0, Math.min(numSlots - 1, Math.floor(mx / cellW)))
                            }

                            onPressed: function(mouse) {
                                var idx = cellAt(mouse.x)
                                dragStartIdx = idx
                                dragFillVal = !rowItem.ps.cells[idx]
                                applyDrag(rowItem.index, idx, idx, dragFillVal)
                            }

                            onPositionChanged: function(mouse) {
                                if (pressed && dragStartIdx >= 0) {
                                    var idx = cellAt(mouse.x)
                                    applyDrag(rowItem.index, dragStartIdx, idx, dragFillVal)
                                }
                            }
                        }

                        // Time label (right of cells)
                        Label {
                            anchors.left: cellRow.right
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: timeLabelW
                            text: fmtSlots(countFilled(ps.cells))
                            font.pixelSize: 11
                            font.family: "Consolas"
                            color: "#6b7280"
                        }
                    }
                }
            }
        }

        // Hint text
        Label {
            text: "Click or drag cells to adjust time  \u2022  each cell = 30 min"
            font.pixelSize: 11
            color: "#9ca3af"
            Layout.topMargin: 8
            Layout.bottomMargin: 4
            visible: projectStates.length > 0
        }

        // Save / Cancel buttons
        RowLayout {
            Layout.topMargin: 8
            spacing: 8
            visible: projectStates.length > 0

            Item { Layout.fillWidth: true }

            Rectangle {
                width: cancelLabel.implicitWidth + 24
                height: 32
                radius: 4
                color: cancelMa.containsMouse ? "#f3f4f6" : "#ffffff"
                border.color: "#e5e7eb"
                border.width: 1

                Label {
                    id: cancelLabel
                    anchors.centerIn: parent
                    text: "Cancel"
                    font.pixelSize: 13
                    color: "#6b7280"
                }

                MouseArea {
                    id: cancelMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.back()
                }
            }

            Rectangle {
                width: saveLabel.implicitWidth + 24
                height: 32
                radius: 4
                color: saveMa.containsMouse ? "#374151" : "#1f2937"

                Label {
                    id: saveLabel
                    anchors.centerIn: parent
                    text: "Save"
                    font.pixelSize: 13
                    color: "#ffffff"
                }

                MouseArea {
                    id: saveMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: saveAll()
                }
            }
        }
    }
}
