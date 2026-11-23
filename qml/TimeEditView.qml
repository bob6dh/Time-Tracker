import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "SessionUtils.js" as SU

Item {
    id: root
    objectName: "timeEditView"

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
        "#4f46e5", "#e07b54", "#10b981", "#9b59b6",
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
    // Sessions of one project currently in the model, optionally skipping one
    // model row (the block being resized).
    function sessionsFor(projIdx, excludeRow) {
        var out = []
        for (var i = 0; i < sessionModel.count; i++) {
            if (i === excludeRow) continue
            var it = sessionModel.get(i)
            if (it.projIdx === projIdx) out.push({ start: it.start, end: it.end })
        }
        return out
    }
    function markModified(projIdx) {
        var mp = modifiedProjects
        mp[projIdx] = true
        modifiedProjects = mp
    }
    function recalcColWidth() {
        if (projectMeta.length === 0) { colWidth = 80; return }
        var avail = root.width - timeLabelW
        colWidth = Math.max(56, avail / projectMeta.length)
    }

    function loadData() {
        sessionModel.clear()
        var modified = {}
        var data = backend.getDayData(dayKey)
        var meta = []
        var descs = {}
        if (data && data.length > 0) {
            for (var pi = 0; pi < data.length; pi++) {
                var proj = data[pi]
                meta.push({ name: proj.project, color: colorPalette[pi % colorPalette.length] })
                descs[proj.project] = proj.description || ""
                var raw = []
                var sessions = proj.sessions || []
                for (var si = 0; si < sessions.length; si++) {
                    var s = sessions[si]
                    raw.push({ start: Math.max(s.start, startHour * 60),
                               end:   Math.min(s.end,   endHour   * 60),
                               task:  s.task })
                }
                // Overlapping blocks (left behind by older versions of this view)
                // stack on top of each other, so the lower one can't be reached
                // to delete, and they double-count time. Merge them, and mark the
                // project modified so Save writes the cleanup back.
                var clean = SU.normalize(raw)
                if (clean.length !== sessions.length) modified[pi] = true
                for (var ci = 0; ci < clean.length; ci++) {
                    // ListModel can't infer a role's type from a literal null in append(),
                    // so "" is used as the "no task" sentinel here (never null) — converted
                    // back to null only when serialized to JSON in saveAll().
                    sessionModel.append({ projIdx: pi, start: clean[ci].start, end: clean[ci].end,
                                          task: clean[ci].task || "" })
                }
            }
        }
        projectMeta = meta
        modifiedProjects = modified
        descriptions = descs
        recalcColWidth()
    }

    function saveAll() {
        // Reconstruct sessions per project from sessionModel
        var byProj = {}
        for (var i = 0; i < sessionModel.count; i++) {
            var item = sessionModel.get(i)
            if (!byProj[item.projIdx]) byProj[item.projIdx] = []
            byProj[item.projIdx].push({ start: item.start, end: item.end, task: item.task ? item.task : null })
        }
        for (var pi = 0; pi < projectMeta.length; pi++) {
            var projName = projectMeta[pi].name
            if (modifiedProjects[pi]) {
                var sessions = SU.normalize(byProj[pi] || []).map(function(x) {
                    return { start: x.start, end: x.end, task: x.task ? x.task : null }
                })
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
            color: backMa.containsMouse ? "#0f172a" : "#64748b"
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
                color: "#0f172a"
                Layout.fillWidth: true
            }

            Rectangle {
                implicitWidth: addProjLbl.implicitWidth + 20
                height: 30; radius: 8
                color: addProjMa.containsMouse ? "#4338ca" : "#4f46e5"
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
            color: "#0f172a"
            Layout.bottomMargin: 10
        }

        // ── Empty state ───────────────────────────────────────────
        // Fills remaining height so the title row stays at the top
        Item {
            visible: projectMeta.length === 0 && !root.showNotes
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No projects logged for this day"
                    font.pixelSize: 14
                    color: "#94a3b8"
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Click \u201c+ Add Project\u201d to log time for a project on this date"
                    font.pixelSize: 12
                    color: "#cbd5e1"
                }
            }
        }

        // ── Daily Notes summary card (clickable, opens full editor) ──
        Rectangle {
            visible: projectMeta.length > 0 && !root.showNotes
            Layout.fillWidth: true
            radius: 10
            color: notesSummaryMa.containsMouse ? "#eef2ff" : "#ffffff"
            border.color: notesSummaryMa.containsMouse ? "#c7d2fe" : "#e2e8f0"
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
                        color: "#64748b"
                        Layout.fillWidth: true
                    }
                    Label {
                        text: "Edit \u2192"
                        font.pixelSize: 11
                        color: "#c7d2fe"
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
                            color: "#1e293b"
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
                            color: note.length > 0 ? "#475569" : "#cbd5e1"
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
                    color: notesBackMa.containsMouse ? "#0f172a" : "#64748b"
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
                    color: "#0f172a"
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
                            radius: 10
                            color: "#ffffff"
                            border.color: "#e2e8f0"
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
                                        color: "#0f172a"
                                    }
                                }

                                // Multiline text area
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 90
                                    radius: 8
                                    color: bigNoteArea.activeFocus ? "#eef2ff" : "#f8fafc"
                                    border.color: bigNoteArea.activeFocus ? "#c7d2fe" : "#e2e8f0"
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
                                            color: "#0f172a"
                                            selectByMouse: true
                                            text: (projectMeta[index] && descriptions[projectMeta[index].name])
                                                  ? descriptions[projectMeta[index].name] : ""

                                            Text {
                                                text: "Add a note about what you worked on..."
                                                color: "#cbd5e1"
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
                    radius: 8
                    color: doneNotesMa.containsMouse ? "#4338ca" : "#4f46e5"
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
                        id: colHeader
                        required property int index
                        width: colWidth; height: headerH
                        property var pm: projectMeta[index] || {name:"", color:"#ccc"}

                        // Hover detection for the whole header cell
                        MouseArea {
                            id: colHeaderMa
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: 1
                            color: colHeader.pm.color
                            opacity: 0.15
                        }
                        Label {
                            anchors.centerIn: parent
                            width: colWidth - (colHeaderMa.containsMouse ? 22 : 8)
                            text: colHeader.pm.name
                            font.pixelSize: 11
                            font.bold: true
                            color: colHeader.pm.color
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // × delete button — visible on hover
                        Rectangle {
                            visible: colHeaderMa.containsMouse
                            anchors { right: parent.right; rightMargin: 3
                                      verticalCenter: parent.verticalCenter }
                            width: 16; height: 16; radius: 8
                            color: delColMa.containsMouse ? "#dc2626" : "#ef4444"
                            z: 4
                            Label {
                                anchors.centerIn: parent
                                text: "\u00d7"
                                font.pixelSize: 11; font.bold: true
                                color: "white"
                            }
                            MouseArea {
                                id: delColMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    removeProjectConfirm.projectName = colHeader.pm.name
                                    removeProjectConfirm.open()
                                }
                            }
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
                            color: index % 2 === 0 ? "#f8fafc" : "#f1f5f9"
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
                            color: "#94a3b8"
                        }
                        // Hour line
                        Rectangle {
                            x: timeLabelW; y: 0
                            width: projectMeta.length * colWidth
                            height: 1
                            color: "#cbd5e1"
                        }
                        // 30-min line
                        Rectangle {
                            x: timeLabelW; y: hourHeight / 2
                            width: projectMeta.length * colWidth
                            height: 1
                            color: "#e2e8f0"
                        }
                    }
                }

                // Column separators
                Repeater {
                    model: projectMeta.length + 1
                    Rectangle {
                        x: timeLabelW + index * colWidth
                        y: 0; width: 1; height: gridH
                        color: "#cbd5e1"
                    }
                }

                // ── Per-column drag-to-create areas ──────────────
                Repeater {
                    model: projectMeta.length

                    Item {
                        id: colBg
                        objectName: "sessionColumn"
                        required property int index
                        x: timeLabelW + index * colWidth + 1
                        y: 0
                        width:  colWidth - 1
                        height: gridH
                        z: 1

                        property bool    isDragging:   false
                        property bool    moved:        false   // past the drag threshold
                        property real    pressY:       0
                        property int     dragStartMin: 0
                        property int     previewStart: 0
                        property int     previewEnd:   0
                        // The empty stretch the new block must stay inside, so it
                        // can never overlap another block of this project.
                        property int     gapLo:        0
                        property int     gapHi:        0

                        function endDrag() {
                            calFlick.interactive = true
                            colBg.isDragging = false
                            colBg.moved = false
                        }

                        MouseArea {
                            anchors.fill: parent
                            preventStealing: true
                            // Blocks (z=2) sit above this, but a block's body passes
                            // clicks through, so presses inside a block land here.
                            // freeGap() returns null for those and they're rejected;
                            // previously they stacked a new block on top.
                            onPressed: function(mouse) {
                                var rawMin = yToMinute(mouse.y)
                                var gap = SU.freeGap(sessionsFor(colBg.index, -1), rawMin,
                                                     startHour * 60, endHour * 60)
                                if (!gap || gap.hi - gap.lo < 1) {
                                    mouse.accepted = false
                                    return
                                }
                                calFlick.interactive = false
                                colBg.gapLo = gap.lo
                                colBg.gapHi = gap.hi
                                colBg.pressY = mouse.y
                                colBg.dragStartMin = clampMin(snapMin(rawMin), gap.lo, gap.hi)
                                colBg.previewStart = colBg.dragStartMin
                                colBg.previewEnd   = colBg.dragStartMin
                                colBg.moved = false
                                colBg.isDragging = true
                            }
                            onPositionChanged: function(mouse) {
                                if (!colBg.isDragging) return
                                // A plain click (e.g. a near-miss on a block's ×)
                                // must not drop a stray block.
                                if (!colBg.moved && Math.abs(mouse.y - colBg.pressY) < 4) return
                                colBg.moved = true
                                var snapped = clampMin(snapMin(yToMinute(mouse.y)), colBg.gapLo, colBg.gapHi)
                                var a = Math.min(snapped, colBg.dragStartMin)
                                var b = Math.max(snapped, colBg.dragStartMin)
                                if (b - a < snapMins) {   // at least one snap step, within the gap
                                    if (snapped >= colBg.dragStartMin) b = Math.min(colBg.gapHi, a + snapMins)
                                    else a = Math.max(colBg.gapLo, b - snapMins)
                                }
                                colBg.previewStart = a
                                colBg.previewEnd   = b
                            }
                            onReleased: function(mouse) {
                                if (colBg.isDragging && colBg.moved
                                    && colBg.previewEnd > colBg.previewStart) {
                                    markModified(colBg.index)
                                    sessionModel.append({
                                        projIdx: colBg.index,
                                        start:   colBg.previewStart,
                                        end:     colBg.previewEnd,
                                        task:    ""
                                    })
                                }
                                colBg.endDrag()
                            }
                            // Grab lost mid-drag (focus change etc.). Without this the
                            // calendar stayed unable to scroll.
                            onCanceled: colBg.endDrag()
                        }

                        // Drag preview
                        Rectangle {
                            visible: colBg.isDragging && colBg.moved
                            x: 2
                            y: minuteToY(colBg.previewStart)
                            width:  colBg.width - 4
                            height: Math.max(8, (colBg.previewEnd - colBg.previewStart) * minuteH)
                            color:  projectMeta.length > colBg.index
                                    ? projectMeta[colBg.index].color : "#888"
                            opacity: 0.45
                            radius: 5

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
                        objectName: "sessionBlock"
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
                                width: parent.width - (blockItem.showDelete ? 22 : 6)
                                text: fmtMin(blockItem.start) + " – " + fmtMin(blockItem.end)
                                font.pixelSize: 8
                                color: "white"
                                elide: Text.ElideRight
                            }

                        }

                        // Delete button. Must be a direct child of the block with a z
                        // above the resize handles. It used to live inside the block
                        // rectangle, underneath the handles, which on short (15–30 min)
                        // blocks covered it completely, so clicking × started a resize
                        // instead of deleting.
                        property bool showDelete: blockHover.containsMouse || deleteMa.containsMouse
                                                  || blockItem.height < 30
                        Rectangle {
                            visible: blockItem.showDelete
                            width: 16; height: 16; radius: 8
                            color: deleteMa.containsMouse ? "#dc2626" : "#ef4444"
                            anchors { right: parent.right; rightMargin: 2 }
                            // Short blocks: center the × on the block instead of
                            // hanging it off the top edge.
                            y: blockItem.height < 20 ? (blockItem.height - height) / 2 : 2
                            z: 10
                            Label {
                                anchors.centerIn: parent
                                text: "×"
                                font.pixelSize: 11; font.bold: true
                                color: "white"
                            }
                            MouseArea {
                                id: deleteMa
                                objectName: "sessionDelete"
                                anchors.fill: parent
                                anchors.margins: -3   // slightly larger hit target
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                onClicked: {
                                    markModified(blockItem.projIdx)
                                    sessionModel.remove(blockItem.index)
                                }
                            }
                        }

                        // ── Top resize handle ─────────────────────
                        // Thinner on short blocks and never over the × column, so
                        // the delete button and the block body stay clickable.
                        MouseArea {
                            id: topHandle
                            objectName: "sessionTopHandle"
                            anchors.top: parent.top
                            width: parent.width - 22
                            height: Math.max(3, Math.min(8, Math.floor(blockItem.height / 3)))
                            cursorShape: Qt.SizeVerCursor
                            preventStealing: true
                            z: 3

                            property real pressContentY: 0
                            property int  pressStart:    0
                            property int  minStart:      0   // previous block's end

                            onPressed: function(mouse) {
                                calFlick.interactive = false
                                var pt = mapToItem(gridContent, mouse.x, mouse.y)
                                pressContentY = pt.y
                                pressStart    = blockItem.start
                                minStart = SU.resizeBounds(sessionsFor(blockItem.projIdx, blockItem.index),
                                                           blockItem.start, blockItem.end,
                                                           startHour * 60, endHour * 60).lo
                                blockItem.isResizingTop = true
                            }
                            onPositionChanged: function(mouse) {
                                if (!pressed) return
                                var pt    = mapToItem(gridContent, mouse.x, mouse.y)
                                var delta = pt.y - pressContentY
                                var newS  = snapMin(pressStart + delta / minuteH)
                                // Can't grow into the previous block, or shrink below one
                                // snap step.
                                // (A block already shorter than a step can't shrink further.)
                                var maxS = Math.max(Math.min(pressStart, blockItem.end - 1),
                                                    blockItem.end - snapMins)
                                newS = clampMin(newS, minStart, maxS)
                                if (newS !== blockItem.start) {
                                    sessionModel.setProperty(blockItem.index, "start", newS)
                                    markModified(blockItem.projIdx)
                                }
                            }
                            onReleased: {
                                calFlick.interactive = true
                                blockItem.isResizingTop = false
                            }
                            onCanceled: {
                                calFlick.interactive = true
                                blockItem.isResizingTop = false
                            }
                        }

                        // ── Bottom resize handle ──────────────────
                        MouseArea {
                            id: bottomHandle
                            objectName: "sessionBottomHandle"
                            anchors.bottom: parent.bottom
                            width: parent.width - 22
                            height: Math.max(3, Math.min(8, Math.floor(blockItem.height / 3)))
                            cursorShape: Qt.SizeVerCursor
                            preventStealing: true
                            z: 3

                            property real pressContentY: 0
                            property int  pressEnd:      0
                            property int  maxEnd:        0   // next block's start

                            onPressed: function(mouse) {
                                calFlick.interactive = false
                                var pt = mapToItem(gridContent, mouse.x, mouse.y)
                                pressContentY = pt.y
                                pressEnd      = blockItem.end
                                maxEnd = SU.resizeBounds(sessionsFor(blockItem.projIdx, blockItem.index),
                                                         blockItem.start, blockItem.end,
                                                         startHour * 60, endHour * 60).hi
                                blockItem.isResizingBottom = true
                            }
                            onPositionChanged: function(mouse) {
                                if (!pressed) return
                                var pt    = mapToItem(gridContent, mouse.x, mouse.y)
                                var delta = pt.y - pressContentY
                                var newE  = snapMin(pressEnd + delta / minuteH)
                                // Can't grow into the next block, or shrink below one snap step.
                                var minE = Math.min(Math.max(pressEnd, blockItem.start + 1),
                                                    blockItem.start + snapMins)
                                newE = clampMin(newE, minE, maxEnd)
                                if (newE !== blockItem.end) {
                                    sessionModel.setProperty(blockItem.index, "end", newE)
                                    markModified(blockItem.projIdx)
                                }
                            }
                            onReleased: {
                                calFlick.interactive = true
                                blockItem.isResizingBottom = false
                            }
                            onCanceled: {
                                calFlick.interactive = true
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
            color: "#94a3b8"
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
                radius: 8
                color: cancelMa.containsMouse ? "#f1f5f9" : "#ffffff"
                border.color: "#e2e8f0"; border.width: 1
                Label { id: cancelLbl; anchors.centerIn: parent
                        text: "Cancel"; font.pixelSize: 13; color: "#64748b" }
                MouseArea { id: cancelMa; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.back() }
            }

            Rectangle {
                width: saveLbl.implicitWidth + 24; height: 32
                radius: 8
                color: saveMa.containsMouse ? "#4338ca" : "#4f46e5"
                Label { id: saveLbl; anchors.centerIn: parent
                        text: "Save"; font.pixelSize: 13; color: "#ffffff" }
                MouseArea { id: saveMa; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: saveAll() }
            }
        }
    }

    // ── Remove project from day — confirmation popup ─────────────
    Popup {
        id: removeProjectConfirm
        anchors.centerIn: parent
        width: 280
        padding: 0
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property string projectName: ""

        background: Rectangle {
            radius: 8; color: "#ffffff"
            border.color: "#e2e8f0"; border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 0

            Label {
                text: "Remove from this day?"
                font.pixelSize: 16; font.bold: true
                color: "#0f172a"
                Layout.topMargin: 20; Layout.leftMargin: 16; Layout.rightMargin: 16
                Layout.bottomMargin: 8
            }
            Label {
                text: "\u201c" + removeProjectConfirm.projectName + "\u201d and all its time blocks for this day will be deleted."
                font.pixelSize: 13; color: "#64748b"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.leftMargin: 16; Layout.rightMargin: 16
                Layout.bottomMargin: 20
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 16; Layout.rightMargin: 16; Layout.bottomMargin: 16
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true; height: 38; radius: 8
                    color: rmCancelMa.containsMouse ? "#f1f5f9" : "#ffffff"
                    border.color: "#e2e8f0"; border.width: 1
                    Label { anchors.centerIn: parent; text: "Cancel"
                            font.pixelSize: 13; color: "#64748b" }
                    MouseArea {
                        id: rmCancelMa; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: removeProjectConfirm.close()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; height: 38; radius: 8
                    color: rmConfirmMa.containsMouse ? "#b91c1c" : "#dc2626"
                    Label { anchors.centerIn: parent; text: "Remove"
                            font.pixelSize: 13; color: "white" }
                    MouseArea {
                        id: rmConfirmMa; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            backend.removeProjectFromDay(root.dayKey, removeProjectConfirm.projectName)
                            root.loadData()
                            removeProjectConfirm.close()
                        }
                    }
                }
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
            border.color: "#e2e8f0"
            border.width: 1
        }

        contentItem: Column {
            width: addProjectPopup.width
            spacing: 0

            // Header
            Item {
                width: parent.width
                height: 36
                Rectangle { anchors.fill: parent; color: "#f8fafc";
                            radius: 8
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width;
                                        height: 8; color: "#f8fafc" } }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 12
                    text: "Add project to this day"
                    font.pixelSize: 11; font.bold: true
                    color: "#64748b"
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#e2e8f0" }
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
                        color: pickerItemMa.containsMouse && !alreadyAdded ? "#eef2ff" : "transparent"
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 12
                        text: name
                        font.pixelSize: 13
                        color: alreadyAdded ? "#cbd5e1" : "#0f172a"
                        width: parent.width - (alreadyAdded ? 70 : 20)
                        elide: Text.ElideRight
                    }
                    Label {
                        visible: alreadyAdded
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right; anchors.rightMargin: 12
                        text: "added"
                        font.pixelSize: 11
                        color: "#cbd5e1"
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
                    color: "#94a3b8"
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Item { width: parent.width; height: 6 }  // bottom padding
        }
    }
}
