import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property string dayKey: ""
    signal back()
    signal saved()

    // ── Grid constants ────────────────────────────────────────────
    readonly property int startHour:    0          // 12 AM (midnight)
    readonly property int endHour:      24         // 12 AM next day
    readonly property int hourHeight:   44         // px per hour
    readonly property real minuteH:     hourHeight / 60.0
    readonly property int snapMins:     15         // snap resolution
    readonly property real timeLabelW:  42
    readonly property real headerH:     28

    property real colWidth: 80  // recalculated after load
    property int  gridH:    (endHour - startHour) * hourHeight

    // ── Project metadata ──────────────────────────────────────────
    // [{name, color}]  — does NOT include sessions (those live in sessionModel)
    property var projectMeta: []

    // Which project indices were modified by the user
    property var modifiedProjects: ({})

    // ── Flat session ListModel ────────────────────────────────────
    // Fields: projIdx, start, end
    ListModel { id: sessionModel }

    // ── Color palette ─────────────────────────────────────────────
    readonly property var palette: [
        "#4a86c8", "#e07b54", "#5cb85c", "#9b59b6",
        "#e67e22", "#1abc9c", "#e74c3c", "#f39c12"
    ]

    // ── Lifecycle ────────────────────────────────────────────────
    Component.onCompleted: { if (dayKey !== "") loadData() }
    onDayKeyChanged:        { if (dayKey !== "") loadData() }
    onWidthChanged:         recalcColWidth()

    // ── Helper functions ─────────────────────────────────────────
    function minuteToY(min) {
        return (min - startHour * 60) * minuteH
    }
    function yToMinute(y) {
        return startHour * 60 + y / minuteH
    }
    function snapMin(min) {
        return Math.round(min / snapMins) * snapMins
    }
    function clampMin(min, lo, hi) {
        return Math.max(lo, Math.min(hi, min))
    }
    function fmtMin(min) {
        var h = Math.floor(min / 60)
        var m = min % 60
        var ap = h >= 12 ? "PM" : "AM"
        var h12 = h % 12 || 12
        return h12 + ":" + (m < 10 ? "0" : "") + m + " " + ap
    }
    function recalcColWidth() {
        if (projectMeta.length === 0) { colWidth = 80; return }
        var avail = root.width - timeLabelW
        colWidth = Math.max(56, avail / projectMeta.length)
    }

    function loadData() {
        sessionModel.clear()
        modifiedProjects = {}
        var data = backend.getDayData(dayKey)
        var meta = []
        if (data && data.length > 0) {
            for (var pi = 0; pi < data.length; pi++) {
                var proj = data[pi]
                meta.push({ name: proj.project, color: palette[pi % palette.length] })
                var sessions = proj.sessions || []
                for (var si = 0; si < sessions.length; si++) {
                    var s = sessions[si]
                    // Only include sessions within the display range
                    var sStart = Math.max(s.start, startHour * 60)
                    var sEnd   = Math.min(s.end,   endHour   * 60)
                    if (sEnd > sStart) {
                        sessionModel.append({ projIdx: pi, start: sStart, end: sEnd })
                    }
                }
            }
        }
        projectMeta = meta
        recalcColWidth()
    }

    function saveAll() {
        // Reconstruct sessions per project from sessionModel
        var byProj = {}
        for (var i = 0; i < sessionModel.count; i++) {
            var item = sessionModel.get(i)
            if (!byProj[item.projIdx]) byProj[item.projIdx] = []
            byProj[item.projIdx].push({ start: item.start, end: item.end })
        }
        for (var pi = 0; pi < projectMeta.length; pi++) {
            if (modifiedProjects[pi]) {
                var sessions = byProj[pi] || []
                backend.saveDaySessions(dayKey, projectMeta[pi].name, JSON.stringify(sessions))
            }
        }
        root.saved()
    }

    // ── Layout ───────────────────────────────────────────────────
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
            Layout.bottomMargin: 10
        }

        // Empty state
        Label {
            visible: projectMeta.length === 0
            text: "No time logged for this day"
            font.pixelSize: 14
            color: "#adb5bd"
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 20
        }

        // ── Calendar grid ─────────────────────────────────────────
        Flickable {
            id: calFlick
            Layout.fillWidth:  true
            Layout.fillHeight: true
            visible: projectMeta.length > 0
            contentWidth:  timeLabelW + projectMeta.length * colWidth
            contentHeight: headerH + gridH
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            // ── Column headers ────────────────────────────────────
            Row {
                id: headerRow
                y: 0; x: 0; height: headerH
                z: 3  // stay above grid content

                Item { width: timeLabelW; height: headerH }

                Repeater {
                    model: projectMeta.length
                    Item {
                        width: colWidth; height: headerH
                        property var pm: projectMeta[index] || {name:"", color:"#ccc"}
                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: 1
                            color: pm.color
                            opacity: 0.15
                        }
                        Label {
                            anchors.centerIn: parent
                            width: colWidth - 8
                            text: pm.name
                            font.pixelSize: 11
                            font.bold: true
                            color: pm.color
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }

            // ── Grid content (scrollable body) ────────────────────
            Item {
                id: gridContent
                x: 0
                y: headerH
                width:  timeLabelW + projectMeta.length * colWidth
                height: gridH

                // Hour rows: alternating backgrounds + time labels
                Repeater {
                    model: endHour - startHour
                    Item {
                        x: 0; y: index * hourHeight
                        width: gridContent.width; height: hourHeight
                        Rectangle {
                            anchors.fill: parent
                            color: index % 2 === 0 ? "#fafafa" : "#f3f4f6"
                        }
                        // Hour label
                        Label {
                            x: 0; y: 2
                            width: timeLabelW - 4
                            horizontalAlignment: Text.AlignRight
                            text: {
                                var h = startHour + index
                                var ap = h >= 12 ? "p" : "a"
                                var h12 = h % 12 || 12
                                return h12 + ap
                            }
                            font.pixelSize: 9
                            color: "#9ca3af"
                        }
                        // Hour line
                        Rectangle {
                            x: timeLabelW; y: 0
                            width: projectMeta.length * colWidth
                            height: 1
                            color: "#d1d5db"
                        }
                        // 30-min line
                        Rectangle {
                            x: timeLabelW; y: hourHeight / 2
                            width: projectMeta.length * colWidth
                            height: 1
                            color: "#e9ebee"
                        }
                    }
                }

                // Column separators
                Repeater {
                    model: projectMeta.length + 1
                    Rectangle {
                        x: timeLabelW + index * colWidth
                        y: 0; width: 1; height: gridH
                        color: "#d1d5db"
                    }
                }

                // ── Per-column drag-to-create areas ──────────────
                Repeater {
                    model: projectMeta.length

                    Item {
                        id: colBg
                        required property int index
                        x: timeLabelW + index * colWidth + 1
                        y: 0
                        width:  colWidth - 1
                        height: gridH
                        z: 1

                        property bool    isDragging:   false
                        property int     dragStartMin: 0
                        property int     previewStart: 0
                        property int     previewEnd:   0

                        MouseArea {
                            anchors.fill: parent
                            // Blocks (z=2) are above this so they steal events first
                            onPressed: function(mouse) {
                                var rawMin = yToMinute(mouse.y)
                                var snapped = snapMin(rawMin)
                                snapped = clampMin(snapped,
                                    startHour * 60,
                                    endHour   * 60 - snapMins)
                                colBg.dragStartMin = snapped
                                colBg.previewStart = snapped
                                colBg.previewEnd   = snapped + snapMins
                                colBg.isDragging   = true
                            }
                            onPositionChanged: function(mouse) {
                                if (!colBg.isDragging) return
                                var rawMin = yToMinute(mouse.y)
                                var snapped = snapMin(rawMin)
                                snapped = clampMin(snapped, startHour * 60, endHour * 60)
                                if (snapped > colBg.dragStartMin) {
                                    colBg.previewStart = colBg.dragStartMin
                                    colBg.previewEnd   = Math.max(snapped, colBg.dragStartMin + snapMins)
                                } else {
                                    colBg.previewStart = Math.min(snapped, colBg.dragStartMin)
                                    colBg.previewEnd   = colBg.dragStartMin + snapMins
                                }
                            }
                            onReleased: function(mouse) {
                                if (colBg.isDragging
                                    && (colBg.previewEnd - colBg.previewStart) >= snapMins) {
                                    var mp = modifiedProjects
                                    mp[colBg.index] = true
                                    modifiedProjects = mp
                                    sessionModel.append({
                                        projIdx: colBg.index,
                                        start:   colBg.previewStart,
                                        end:     colBg.previewEnd
                                    })
                                }
                                colBg.isDragging = false
                            }
                        }

                        // Drag preview
                        Rectangle {
                            visible: colBg.isDragging
                            x: 2
                            y: minuteToY(colBg.previewStart)
                            width:  colBg.width - 4
                            height: Math.max(8, (colBg.previewEnd - colBg.previewStart) * minuteH)
                            color:  projectMeta.length > colBg.index
                                    ? projectMeta[colBg.index].color : "#888"
                            opacity: 0.45
                            radius: 3

                            Label {
                                visible: parent.height > 16
                                anchors { left: parent.left; leftMargin: 3; top: parent.top; topMargin: 2 }
                                text: fmtMin(colBg.previewStart) + " – " + fmtMin(colBg.previewEnd)
                                font.pixelSize: 8
                                color: "white"
                                elide: Text.ElideRight
                                width: parent.width - 6
                            }
                        }
                    }
                }

                // ── Session blocks ────────────────────────────────
                Repeater {
                    model: sessionModel

                    Item {
                        id: blockItem
                        required property int index

                        x: timeLabelW + model.projIdx * colWidth + 3
                        y: minuteToY(model.start)
                        width:  colWidth - 6
                        height: Math.max(8, (model.end - model.start) * minuteH)
                        z: 2   // above column backgrounds

                        property bool isSelected:       false
                        property bool isResizingTop:    false
                        property bool isResizingBottom: false
                        property color blockColor: projectMeta.length > model.projIdx
                                                   ? projectMeta[model.projIdx].color : "#888"

                        // Main block rectangle
                        Rectangle {
                            anchors.fill: parent
                            color:   blockItem.blockColor
                            opacity: (blockItem.isResizingTop || blockItem.isResizingBottom) ? 0.55 : 1.0
                            radius:  3
                            clip:    true

                            // Time label
                            Label {
                                visible: blockItem.height > 16
                                anchors { left: parent.left; leftMargin: 3
                                          top: parent.top; topMargin: 2 }
                                width: parent.width - (blockItem.isSelected ? 22 : 6)
                                text: fmtMin(model.start) + " – " + fmtMin(model.end)
                                font.pixelSize: 8
                                color: "white"
                                elide: Text.ElideRight
                            }

                            // Delete button (visible when selected)
                            Rectangle {
                                visible: blockItem.isSelected
                                width: 16; height: 16; radius: 8
                                color: "#ef4444"
                                anchors { top: parent.top; right: parent.right
                                          topMargin: 2; rightMargin: 2 }
                                z: 4
                                Label {
                                    anchors.centerIn: parent
                                    text: "\u00d7"
                                    font.pixelSize: 11; font.bold: true
                                    color: "white"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    z: 5
                                    onClicked: {
                                        var mp = modifiedProjects
                                        mp[model.projIdx] = true
                                        modifiedProjects = mp
                                        sessionModel.remove(blockItem.index)
                                    }
                                }
                            }
                        }

                        // Body click → select / deselect
                        MouseArea {
                            anchors.fill:         parent
                            anchors.topMargin:    8
                            anchors.bottomMargin: 8
                            z: 2
                            onClicked: blockItem.isSelected = !blockItem.isSelected
                        }

                        // ── Top resize handle ─────────────────────
                        MouseArea {
                            id: topHandle
                            anchors.top: parent.top
                            width: parent.width; height: 8
                            cursorShape: Qt.SizeVerCursor
                            z: 3

                            property real pressContentY: 0
                            property int  pressStart:    0

                            onPressed: function(mouse) {
                                var pt = mapToItem(gridContent, mouse.x, mouse.y)
                                pressContentY       = pt.y
                                pressStart          = model.start
                                blockItem.isResizingTop = true
                            }
                            onPositionChanged: function(mouse) {
                                if (!pressed) return
                                var pt    = mapToItem(gridContent, mouse.x, mouse.y)
                                var delta = pt.y - pressContentY
                                var newS  = snapMin(pressStart + delta / minuteH)
                                newS = clampMin(newS, startHour * 60, model.end - snapMins)
                                sessionModel.setProperty(blockItem.index, "start", newS)
                            }
                            onReleased: {
                                var mp = modifiedProjects
                                mp[model.projIdx] = true
                                modifiedProjects = mp
                                blockItem.isResizingTop = false
                            }
                        }

                        // ── Bottom resize handle ──────────────────
                        MouseArea {
                            id: bottomHandle
                            anchors.bottom: parent.bottom
                            width: parent.width; height: 8
                            cursorShape: Qt.SizeVerCursor
                            z: 3

                            property real pressContentY: 0
                            property int  pressEnd:      0

                            onPressed: function(mouse) {
                                var pt = mapToItem(gridContent, mouse.x, mouse.y)
                                pressContentY          = pt.y
                                pressEnd               = model.end
                                blockItem.isResizingBottom = true
                            }
                            onPositionChanged: function(mouse) {
                                if (!pressed) return
                                var pt    = mapToItem(gridContent, mouse.x, mouse.y)
                                var delta = pt.y - pressContentY
                                var newE  = snapMin(pressEnd + delta / minuteH)
                                newE = clampMin(newE, model.start + snapMins, endHour * 60)
                                sessionModel.setProperty(blockItem.index, "end", newE)
                            }
                            onReleased: {
                                var mp = modifiedProjects
                                mp[model.projIdx] = true
                                modifiedProjects = mp
                                blockItem.isResizingBottom = false
                            }
                        }
                    }
                }
            } // gridContent
        } // Flickable

        // Hint
        Label {
            visible: projectMeta.length > 0
            text: "Drag in column to add time  \u2022  click block to delete  \u2022  drag block edges to resize"
            font.pixelSize: 10
            color: "#9ca3af"
            Layout.topMargin: 6
            Layout.bottomMargin: 2
        }

        // ── Save / Cancel buttons ─────────────────────────────────
        RowLayout {
            visible: projectMeta.length > 0
            Layout.topMargin: 6
            spacing: 8

            Item { Layout.fillWidth: true }

            Rectangle {
                width: cancelLbl.implicitWidth + 24; height: 32
                radius: 4
                color: cancelMa.containsMouse ? "#f3f4f6" : "#ffffff"
                border.color: "#e5e7eb"; border.width: 1
                Label { id: cancelLbl; anchors.centerIn: parent
                        text: "Cancel"; font.pixelSize: 13; color: "#6b7280" }
                MouseArea { id: cancelMa; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.back() }
            }

            Rectangle {
                width: saveLbl.implicitWidth + 24; height: 32
                radius: 4
                color: saveMa.containsMouse ? "#374151" : "#1f2937"
                Label { id: saveLbl; anchors.centerIn: parent
                        text: "Save"; font.pixelSize: 13; color: "#ffffff" }
                MouseArea { id: saveMa; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: saveAll() }
            }
        }
    }
}
