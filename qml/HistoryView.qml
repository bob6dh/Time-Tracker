import QtQuick
import QtQuick.Controls

Item {
    id: root
    signal daySelected(string dayKey)

    // {dateKey: true} — rebuilt whenever history changes
    property var datesSet: ({})
    // [{year, month}] newest-first — drives the month Repeater
    property var monthList: []

    readonly property string todayKey: {
        var d = new Date()
        return d.getFullYear() + "-" + _pad(d.getMonth() + 1) + "-" + _pad(d.getDate())
    }
    readonly property color accent: "#4a86c8"

    function _pad(n) { return n < 10 ? "0" + n : "" + n }

    // Rebuild the date set and month list from backend data
    function buildData() {
        var keys = backend.getDatesWithData()
        var set = {}
        for (var i = 0; i < keys.length; i++) set[keys[i]] = true
        datesSet = set

        var today = new Date()
        var curY = today.getFullYear()
        var curM = today.getMonth() + 1

        // Find earliest logged month
        var eY = curY, eM = curM
        for (var j = 0; j < keys.length; j++) {
            var y = parseInt(keys[j].substring(0, 4))
            var m = parseInt(keys[j].substring(5, 7))
            if (y < eY || (y === eY && m < eM)) { eY = y; eM = m }
        }

        // Build list from current month back to earliest
        var months = []
        var wy = curY, wm = curM
        while (wy > eY || (wy === eY && wm >= eM)) {
            months.push({ year: wy, month: wm })
            wm--
            if (wm === 0) { wm = 12; wy-- }
        }
        monthList = months
    }

    // Returns an array of {day, key} for every cell in the month grid
    // (Sunday-first, padded to a multiple of 7)
    function cellsForMonth(year, month) {
        var first  = new Date(year, month - 1, 1)
        var offset = first.getDay()                         // 0 = Sunday
        var days   = new Date(year, month, 0).getDate()    // days in month
        var cells  = []
        for (var i = 0; i < offset; i++)
            cells.push({ day: 0, key: "" })
        for (var d = 1; d <= days; d++)
            cells.push({ day: d, key: year + "-" + _pad(month) + "-" + _pad(d) })
        while (cells.length % 7 !== 0)
            cells.push({ day: 0, key: "" })
        return cells
    }

    Component.onCompleted: buildData()

    // Refresh when any day is saved or timer stops
    Connections {
        target: backend.historyModel
        function onModelReset() { root.buildData() }
    }

    // ── Scrollable calendar ───────────────────────────────────────
    Flickable {
        anchors.fill: parent
        contentHeight: monthsCol.implicitHeight
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
            id: monthsCol
            width: parent.width
            spacing: 0

            // ── "No history yet" ─────────────────────────────────
            Label {
                visible: root.monthList.length > 0
                         && Object.keys(root.datesSet).length === 0
                width: monthsCol.width
                topPadding: 12
                bottomPadding: 8
                leftPadding: 4
                text: "No time logged yet — start a project to begin tracking."
                font.pixelSize: 13
                color: "#9ca3af"
                wrapMode: Text.WordWrap
            }

            // ── One block per month ───────────────────────────────
            Repeater {
                model: root.monthList

                Item {
                    id: monthItem
                    required property var modelData   // {year, month}
                    required property int index

                    readonly property int myYear:  modelData.year
                    readonly property int myMonth: modelData.month

                    width:  monthsCol.width
                    height: monthBlock.height + (index === 0 ? 0 : 20)

                    Column {
                        id: monthBlock
                        width: parent.width
                        anchors.bottom: parent.bottom
                        spacing: 0

                        // Divider between months (skip before first)
                        Rectangle {
                            visible: monthItem.index > 0
                            width: parent.width
                            height: 1
                            color: "#e5e7eb"
                        }

                        // Month label
                        Label {
                            width: parent.width
                            topPadding: monthItem.index > 0 ? 18 : 0
                            bottomPadding: 10
                            text: Qt.formatDate(
                                    new Date(monthItem.myYear, monthItem.myMonth - 1, 1),
                                    "MMMM yyyy")
                            font.pixelSize: 17
                            font.bold: true
                            color: "#1f2937"
                        }

                        // Day-of-week headers
                        Row {
                            width: parent.width
                            Repeater {
                                model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                                Item {
                                    width:  monthsCol.width / 7
                                    height: 24
                                    Label {
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.pixelSize: 11
                                        color: "#9ca3af"
                                    }
                                }
                            }
                        }

                        // Day cells
                        Grid {
                            id: dayGrid
                            columns: 7
                            width: parent.width
                            // Store cells as a property so child Repeater can read it
                            property var cells: root.cellsForMonth(monthItem.myYear, monthItem.myMonth)

                            Repeater {
                                model: dayGrid.cells

                                Item {
                                    required property var modelData   // {day, key}

                                    readonly property bool isEmpty:  modelData.day === 0
                                    readonly property bool hasData:  !isEmpty && !!root.datesSet[modelData.key]
                                    readonly property bool isToday:  modelData.key === root.todayKey

                                    width:  monthsCol.width / 7
                                    height: width

                                    // Hover highlight (all clickable days)
                                    Rectangle {
                                        visible: !isEmpty && dayMa.containsMouse && !hasData && !isToday
                                        anchors.centerIn: parent
                                        width: 36; height: 36; radius: 18
                                        color: "#f3f4f6"
                                    }

                                    // Filled circle (has data) or outline ring (today)
                                    Rectangle {
                                        visible: !isEmpty && (hasData || isToday)
                                        anchors.centerIn: parent
                                        width: 36; height: 36; radius: 18
                                        color:        hasData ? root.accent : "transparent"
                                        border.color: isToday && !hasData ? root.accent : "transparent"
                                        border.width: 2
                                    }

                                    // Day number
                                    Label {
                                        visible: !isEmpty
                                        anchors.centerIn: parent
                                        text: modelData.day
                                        font.pixelSize: 14
                                        font.bold: hasData || isToday
                                        color: hasData ? "#ffffff"
                                             : isToday ? root.accent
                                             : "#374151"
                                    }

                                    // Click — any non-empty day
                                    MouseArea {
                                        id: dayMa
                                        anchors.fill: parent
                                        enabled: !isEmpty
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.daySelected(modelData.key)
                                    }
                                }
                            }
                        }

                        Item { height: 8 }   // bottom padding inside month block
                    }
                }
            }

            Item { height: 16 }   // bottom padding of scroll area
        }
    }
}
