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

    // Per-project descriptions: {projName: string}
    property var descriptions: ({})

    // ── Flat session ListModel ────────────────────────────────────
    // Fields: projIdx, start, end
    ListModel { id: sessionModel }

    // ── Color palette ─────────────────────────────────────────────
    readonly property var colorPalette: [
        "#4a86c8", "#e07b54", "#5cb85c", "#9b59b6",
        "#e67e22", "#1abc9c", "#e74c3c", "#f39c12"
    ]

    // Notes pane toggle
    property bool showNotes: false

    // ── Lifecycle ────────────────────────────────────────────────
    Component.onCompleted: { if (dayKey !== "") loadData() }
    onDayKeyChanged:        { if (dayKey !== "") { showNotes = false; loadData() } }
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
        var descs = {}
        if (data && data.length > 0) {
            for (var pi = 0; pi < data.length; pi++) {
                var proj = data[pi]
                meta.push({ name: proj.project, color: colorPalette[pi % colorPalette.length] })
                descs[proj.project] = proj.description || ""
                var sessions = proj.sessions || []
                for (var si = 0; si < sessions.length; si++) {
                    var s = sessions[si]
                    var sStart = Math.max(s.start, startHour * 60)
                    var sEnd   = Math.min(s.end,   endHour   * 60)
                    if (sEnd > sStart) {
                        sessionModel.append({ projIdx: pi, start: sStart, end: sEnd })
                    }
                }
            }
        }
        projectMeta = meta
        descriptions = descs
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
            var projName = projectMeta[pi].name
            if (modifiedProjects[pi]) {
                var sessions = byProj[pi] || []
                backend.saveDaySessions(dayKey, projName, JSON.stringify(sessions))
            }
            // Always save descriptions (cheap and avoids tracking a separate dirty flag)
            backend.saveProjectDescription(dayKey, projName, descriptions[projName] || "")
        }
        root.saved()
    }

    // ── Layout ───────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Back link ────────────────────────────────────────────
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

        // ── Title row + Add Project button ───────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 10
            visible: !root.showNotes

            Label {
                text: dayKey !== "" ? backend.dayDetailTitle(dayKey) : ""
                font.pixelSize: 20
                font.bold: true
                color: "#1f2937"
                Layout.fillWidth: true
            }

            Rectangle {
                implicitWidth: addProjLbl.implicitWidth + 20
                height: 30; radius: 4
                color: addProjMa.containsMouse ? "#374151" : "#1f2937"
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Label {
                        text: "+"
                        font.pixelSize: 16; font.bold: true
                        color: "#ffffff"
                    }
                    Label {
                        id: addProjLbl
                        text: "Add Project"
                        font.pixelSize: 12
                        color: "#ffffff"
                    }
                }
                MouseArea {
                    id: addProjMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        addProjectPopup.x = parent.x - addProjectPopup.width + parent.width
                        addProjectPopup.y = parent.y + parent.height + 4
                        addProjectPopup.open()
                    }
                }
            }
        }

        // Title row when notes pane is open (no Add button)
        Label {
            visible: root.showNotes
            text: dayKey !== "" ? backend.dayDetailTitle(dayKey) : ""
            font.pixelSize: 20; font.bold: true
            color: "#1f2937"
            Layout.bottomMargin: 10
        }

        // ── Empty state ───────────────────────────────────────────
        ColumnLayout {
            visible: projectMeta.length === 0 && !root.showNotes
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 40
            spacing: 8
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: "No projects logged for this day"
                font.pixelSize: 14
                color: "#9ca3af"
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: "Click \u201c+ Add Project\u201d to log time for a project on this date"
                font.pixelSize: 12
                color: "#d1d5db"
            }
        }

        // ── Daily Notes summary card (clickable, opens full editor) ──
        Rectangle {
            visible: projectMeta.length > 0 && !root.showNotes
            Layout.fillWidth: true
            radius: 6
            color: notesSummaryMa.containsMouse ? "#f0f4ff" : "#ffffff"
            border.color: notesSummaryMa.containsMouse ? "#93c5fd" : "#e5e7eb"
            border.width: 1
            Layout.bottomMargin: 8
            implicitHeight: notesSummaryCol.implicitHeight + 20

            Behavior on color { ColorAnimation { duration: 80 } }

            MouseArea {
                id: notesSummaryMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.showNotes = true
            }

            ColumnLayout {
                id: notesSummaryCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 6

                // Header row
                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: "Daily Notes"
                        font.pixelSize: 12
                        font.bold: true
                        color: "#6b7280"
                        Layout.fillWidth: true
                    }
                    Label {
                        text: "Edit \u2192"
                        font.pixelSize: 11
                        color: "#93c5fd"
                    }
                }

                // One preview row per project
                Repeater {
                    model: projectMeta.length
                    RowLayout {
                        required property int index
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            width: 3; height: 14; radius: 2
                            color: projectMeta[index] ? projectMeta[index].color : "#ccc"
                        }
                        Label {
                            text: projectMeta[index] ? projectMeta[index].name : ""
                            font.pixelSize: 11
                            font.bold: true
                            color: "#374151"
                            Layout.preferredWidth: 80
                            elide: Text.ElideRight
                        }
                        Label {
                            property string note: (projectMeta[index] && descriptions[projectMeta[index].name])
                                                  ? descriptions[projectMeta[index].name] : ""
                            text: note.length > 0 ? (note.length > 60 ? note.substring(0, 60) + "…" : note)
                                                  : "No note"
                            font.pixelSize: 11
                            font.italic: note.length === 0
                            color: note.length > 0 ? "#4b5563" : "#d1d5db"
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }

                Item { height: 2 }
            }
        }

        // ── Full-screen notes editor ──────────────────────────────
        ColumnLayout {
            visible: root.showNotes && projectMeta.length > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            // Header
            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: "\u2190 Back to calendar"
                    font.pixelSize: 13
                    color: notesBackMa.containsMouse ? "#1f2937" : "#6b7280"
                    MouseArea {
                        id: notesBackMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showNotes = false
                    }
                }
                Item { Layout.fillWidth: true }
                Label {
                    text: "Daily Notes"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#1f2937"
                }
                Item { Layout.fillWidth: true }
                // Spacer to balance the back label
                Item { width: 100 }
            }

            // Scrollable per-project note cards
            Flickable {
                id: notesFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: notesEditorCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                ColumnLayout {
                    id: notesEditorCol
                    width: notesFlick.width
                    spacing: 10

                    Repeater {
                        model: projectMeta.length

                        Rectangle {
                            required property int index
                            Layout.fillWidth: true
                            radius: 6
                            color: "#ffffff"
                            border.color: "#e5e7eb"
                            border.width: 1
                            implicitHeight: noteEditorInner.implicitHeight + 20

                            ColumnLayout {
                                id: noteEditorInner
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                                spacing: 6

                                // Project name with color swatch
                                RowLayout {
                                    spacing: 8
                                    Rectangle {
                                        width: 4; height: 16; radius: 2
                                        color: projectMeta[index] ? projectMeta[index].color : "#ccc"
                                    }
                                    Label {
                                        text: projectMeta[index] ? projectMeta[index].name : ""
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: "#1f2937"
                                    }
                                }

                                // Multiline text area
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 90
                                    radius: 4
                                    color: bigNoteArea.activeFocus ? "#f0f4ff" : "#f9fafb"
                                    border.color: bigNoteArea.activeFocus ? "#93c5fd" : "#e5e7eb"
                                    border.width: 1

                                    Flickable {
                                        id: bigNoteFlick
                                        anchors { fill: parent; margins: 8 }
                                        contentHeight: bigNoteArea.implicitHeight
                                        clip: true
                                        boundsBehavior: Flickable.StopAtBounds
                                        flickableDirection: Flickable.VerticalFlick

                                        TextEdit {
                                            id: bigNoteArea
                                            width: bigNoteFlick.width
                                            wrapMode: TextEdit.Wrap
                                            font.pixelSize: 13
                                            color: "#1f2937"
                                            selectByMouse: true
                                            text: (projectMeta[index] && descriptions[projectMeta[index].name])
                                                  ? descriptions[projectMeta[index].name] : ""

                                            Text {
                                                text: "Add a note about what you worked on..."
                                                color: "#d1d5db"
                                                font.pixelSize: 13
                                                visible: !bigNoteArea.text && !bigNoteArea.activeFocus
                                            }

                                            onTextChanged: {
                                                if (projectMeta[index]) {
                                                    var d = descriptions
                                                    d[projectMeta[index].name] = text
                                                    descriptions = d
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item { height: 4 }  // bottom padding
                }
            }

            // Done button
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: doneNotesLbl.implicitWidth + 32; height: 34
                    radius: 4
                    color: doneNotesMa.containsMouse ? "#374151" : "#1f2937"
                    Label {
                        id: doneNotesLbl
                        anchors.centerIn: parent
                        text: "Done"
                        font.pixelSize: 13
                        color: "white"
                    }
                    MouseArea {
                        id: doneNotesMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showNotes = false
                    }
                }
            }
        }

        // ── Calendar grid ─────────────────────────────────────────
        Flickable {
            id: calFlick
            Layout.fillWidth:  true
            Layout.fillHeight: true
            visible: projectMeta.length > 0 && !root.showNotes
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
                            preventStealing: true
                            // Blocks (z=2) are above this so they steal events first
                            onPressed: function(mouse) {
                                calFlick.interactive = false
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
                                calFlick.interactive = true
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
                        required property int projIdx
                        required property int start
                        required property int end

                        x: timeLabelW + projIdx * colWidth + 3
                        y: minuteToY(start)
                        width:  colWidth - 6
                        height: Math.max(8, (end - start) * minuteH)
                        z: 2   // above column backgrounds

                        property bool isResizingTop:    false
                        property bool isResizingBottom: false
                        property color blockColor: projectMeta.length > projIdx
                                                   ? projectMeta[projIdx].color : "#888"

                        // Hover detection for the whole block
                        MouseArea {
                            id: blockHover
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton  // pass clicks through to children
                        }

                        // Main block rectangle
                        Rectangle {
                            anchors.fill: parent
                            color:   blockItem.blockColor
                            opacity: (blockItem.isResizingTop || blockItem.isResizingBottom) ? 0.55 : 1.0
                            radius:  3
                            clip:    true

                            // Time label — shrinks when × is visible
                            Label {
                                visible: blockItem.height > 16
                                anchors { left: parent.left; leftMargin: 3
                                          top: parent.top; topMargin: 2 }
                                width: parent.width - (showDelete ? 22 : 6)
                                property bool showDelete: blockHover.containsMouse || blockItem.height < 30
                                text: fmtMin(blockItem.start) + " – " + fmtMin(blockItem.end)
                                font.pixelSize: 8
                                color: "white"
                                elide: Text.ElideRight
                            }

                            // Delete button — visible on hover or when block is too small to hover
                            Rectangle {
                                visible: blockHover.containsMouse || blockItem.height < 30
                                width: 16; height: 16; radius: 8
                                color: deleteMa.containsMouse ? "#dc2626" : "#ef4444"
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
                                    id: deleteMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    z: 5
                                    onClicked: {
                                        var mp = modifiedProjects
                                        mp[blockItem.projIdx] = true
                                        modifiedProjects = mp
                                        sessionModel.remove(blockItem.index)
                                    }
                                }
                            }
                        }

                        // ── Top resize handle ─────────────────────
                        MouseArea {
                            id: topHandle
                            anchors.top: parent.top
                            width: parent.width; height: 10
                            cursorShape: Qt.SizeVerCursor
                            preventStealing: true
                            z: 3

                            property real pressContentY: 0
                            property int  pressStart:    0

                            onPressed: function(mouse) {
                                calFlick.interactive = false
                                var pt = mapToItem(gridContent, mouse.x, mouse.y)
                                pressContentY           = pt.y
                                pressStart              = blockItem.start
                                blockItem.isResizingTop = true
                            }
                            onPositionChanged: function(mouse) {
                                if (!pressed) return
                                var pt    = mapToItem(gridContent, mouse.x, mouse.y)
                                var delta = pt.y - pressContentY
                                var newS  = snapMin(pressStart + delta / minuteH)
                                newS = clampMin(newS, startHour * 60, blockItem.end - snapMins)
                                sessionModel.setProperty(blockItem.index, "start", newS)
                            }
                            onReleased: {
                                calFlick.interactive = true
                                var mp = modifiedProjects
                                mp[blockItem.projIdx] = true
                                modifiedProjects = mp
                                blockItem.isResizingTop = false
                            }
                        }

                        // ── Bottom resize handle ──────────────────
                        MouseArea {
                            id: bottomHandle
                            anchors.bottom: parent.bottom
                            width: parent.width; height: 10
                            cursorShape: Qt.SizeVerCursor
                            preventStealing: true
                            z: 3

                            property real pressContentY: 0
                            property int  pressEnd:      0

                            onPressed: function(mouse) {
                                calFlick.interactive = false
                                var pt = mapToItem(gridContent, mouse.x, mouse.y)
                                pressContentY              = pt.y
                                pressEnd                   = blockItem.end
                                blockItem.isResizingBottom = true
                            }
                            onPositionChanged: function(mouse) {
                                if (!pressed) return
                                var pt    = mapToItem(gridContent, mouse.x, mouse.y)
                                var delta = pt.y - pressContentY
                                var newE  = snapMin(pressEnd + delta / minuteH)
                                newE = clampMin(newE, blockItem.start + snapMins, endHour * 60)
                                sessionModel.setProperty(blockItem.index, "end", newE)
                            }
                            onReleased: {
                                calFlick.interactive = true
                                var mp = modifiedProjects
                                mp[blockItem.projIdx] = true
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
            visible: projectMeta.length > 0 && !root.showNotes
            text: "Drag in column to add time  \u2022  hover block and click \u00d7 to delete  \u2022  drag block edges to resize"
            font.pixelSize: 10
            color: "#9ca3af"
            Layout.topMargin: 6
            Layout.bottomMargin: 2
        }

        // ── Save / Cancel buttons ─────────────────────────────────
        RowLayout {
            visible: projectMeta.length > 0 && !root.showNotes
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

    // ── Add Project picker popup ──────────────────────────────────
    Popup {
        id: addProjectPopup
        width: 230
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 8
            color: "#ffffff"
            border.color: "#e5e7eb"
            border.width: 1
        }

        contentItem: Column {
            width: addProjectPopup.width
            spacing: 0

            // Header
            Item {
                width: parent.width
                height: 36
                Rectangle { anchors.fill: parent; color: "#f9fafb";
                            radius: 8
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width;
                                        height: 8; color: "#f9fafb" } }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 12
                    text: "Add project to this day"
                    font.pixelSize: 11; font.bold: true
                    color: "#6b7280"
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#e5e7eb" }
            }

            // Project list
            ListView {
                id: projPickerList
                width: parent.width
                height: Math.min(contentHeight, 240)
                clip: true
                model: backend.projectModel

                delegate: Item {
                    required property string name
                    required property int index
                    width: projPickerList.width
                    height: 40

                    property bool alreadyAdded: {
                        for (var i = 0; i < root.projectMeta.length; i++)
                            if (root.projectMeta[i].name === name) return true
                        return false
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: pickerItemMa.containsMouse && !alreadyAdded ? "#f0f4ff" : "transparent"
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 12
                        text: name
                        font.pixelSize: 13
                        color: alreadyAdded ? "#d1d5db" : "#1f2937"
                        width: parent.width - (alreadyAdded ? 70 : 20)
                        elide: Text.ElideRight
                    }
                    Label {
                        visible: alreadyAdded
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right; anchors.rightMargin: 12
                        text: "added"
                        font.pixelSize: 11
                        color: "#d1d5db"
                    }
                    MouseArea {
                        id: pickerItemMa
                        anchors.fill: parent
                        enabled: !alreadyAdded
                        hoverEnabled: true
                        cursorShape: alreadyAdded ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: {
                            backend.addProjectToDay(root.dayKey, name)
                            root.loadData()
                            addProjectPopup.close()
                        }
                    }
                }

                // Empty state
                Label {
                    visible: projPickerList.count === 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 12; bottomPadding: 12
                    text: "No projects yet.\nCreate one in the Timer tab."
                    font.pixelSize: 12
                    color: "#9ca3af"
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Item { width: parent.width; height: 6 }  // bottom padding
        }
    }
}
