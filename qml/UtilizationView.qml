import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: utilRoot

    signal back()

    // ── State ─────────────────────────────────────────────────────
    property var utilResult: null
    property var holidayList: []      // array of "YYYY-MM-DD" strings
    property int hoursPerDay: 8

    // Default start = first day of current month, end = today
    property int startYear:  { var d = new Date(); return d.getFullYear() }
    property int startMonth: { var d = new Date(); return d.getMonth() + 1 }
    property int startDay:   1
    property int endYear:    { var d = new Date(); return d.getFullYear() }
    property int endMonth:   { var d = new Date(); return d.getMonth() + 1 }
    property int endDay:     { var d = new Date(); return d.getDate() }

    readonly property var monthNames: ["Jan","Feb","Mar","Apr","May","Jun",
                                       "Jul","Aug","Sep","Oct","Nov","Dec"]

    function daysInMonth(y, m) {
        return new Date(y, m, 0).getDate()  // day 0 of next month = last day of m
    }
    function clampDay(y, m, d) {
        return Math.min(d, daysInMonth(y, m))
    }
    function pad2(n) { return n < 10 ? "0" + n : "" + n }
    function startDateStr() { return startYear + "-" + pad2(startMonth) + "-" + pad2(startDay) }
    function endDateStr()   { return endYear   + "-" + pad2(endMonth)   + "-" + pad2(endDay)   }

    function calculate() {
        errorLabel.text = ""
        utilResult = null
        var sd = startDateStr()
        var ed = endDateStr()
        var holidaysJson = JSON.stringify(holidayList)
        var r = backend.calculateUtilization(sd, ed, hoursPerDay, holidaysJson)
        if (r && r.error) {
            errorLabel.text = r.error
        } else {
            utilResult = r
        }
    }

    function addHoliday() {
        var raw = holidayInput.text.trim()
        if (!raw.match(/^\d{4}-\d{2}-\d{2}$/)) {
            holidayInputError.text = "Use YYYY-MM-DD format"
            return
        }
        holidayInputError.text = ""
        if (holidayList.indexOf(raw) === -1) {
            var updated = holidayList.slice()
            updated.push(raw)
            updated.sort()
            holidayList = updated
        }
        holidayInput.text = ""
    }

    function removeHoliday(dateStr) {
        holidayList = holidayList.filter(function(d) { return d !== dateStr })
    }

    function formatPct(val) {
        if (val < 0) return "N/A"
        return val.toFixed(1) + "%"
    }

    // ── Main layout ───────────────────────────────────────────────
    Flickable {
        anchors.fill: parent
        contentHeight: mainCol.implicitHeight + 20
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: mainCol
            width: parent.width
            spacing: 0

            // Back link
            Label {
                text: "\u2190 Back"
                font.pixelSize: 14
                color: backMa.containsMouse ? "#1f2937" : "#6b7280"
                Layout.bottomMargin: 6
                MouseArea {
                    id: backMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: utilRoot.back()
                }
            }

            Label {
                text: "Utilization Rate"
                font.pixelSize: 22; font.bold: true; color: "#1f2937"
                Layout.bottomMargin: 2
            }
            Label {
                text: "Calculate how much of your time was spent on billable work."
                font.pixelSize: 13; color: "#6b7280"
                Layout.bottomMargin: 20
            }

            // ── Date Range ──────────────────────────────────────────
            Label {
                text: "Date Range"
                font.pixelSize: 15; font.bold: true; color: "#374151"
                Layout.bottomMargin: 8
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Layout.bottomMargin: 20

                // Start date
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: datePickerCol.implicitHeight + 20
                    radius: 6; color: "#f9fafb"
                    border.color: "#e5e7eb"; border.width: 1

                    ColumnLayout {
                        id: datePickerCol
                        anchors { left: parent.left; right: parent.right
                                  top: parent.top; margins: 12 }
                        spacing: 6

                        Label {
                            text: "From"
                            font.pixelSize: 11; color: "#9ca3af"; font.bold: true
                            font.capitalization: Font.AllUppercase
                        }

                        RowLayout {
                            spacing: 4
                            // Year
                            SpinnerField {
                                value: utilRoot.startYear
                                displayText: "" + utilRoot.startYear
                                onIncrement: utilRoot.startYear++
                                onDecrement: if (utilRoot.startYear > 2000) utilRoot.startYear--
                                minWidth: 52
                            }
                            Label { text: "-"; color: "#9ca3af"; font.pixelSize: 14 }
                            // Month
                            SpinnerField {
                                value: utilRoot.startMonth
                                displayText: utilRoot.monthNames[utilRoot.startMonth - 1]
                                onIncrement: {
                                    if (utilRoot.startMonth < 12) utilRoot.startMonth++
                                    else { utilRoot.startMonth = 1; utilRoot.startYear++ }
                                    utilRoot.startDay = utilRoot.clampDay(utilRoot.startYear, utilRoot.startMonth, utilRoot.startDay)
                                }
                                onDecrement: {
                                    if (utilRoot.startMonth > 1) utilRoot.startMonth--
                                    else { utilRoot.startMonth = 12; utilRoot.startYear-- }
                                    utilRoot.startDay = utilRoot.clampDay(utilRoot.startYear, utilRoot.startMonth, utilRoot.startDay)
                                }
                                minWidth: 44
                            }
                            Label { text: "-"; color: "#9ca3af"; font.pixelSize: 14 }
                            // Day
                            SpinnerField {
                                value: utilRoot.startDay
                                displayText: utilRoot.pad2(utilRoot.startDay)
                                onIncrement: {
                                    var maxD = utilRoot.daysInMonth(utilRoot.startYear, utilRoot.startMonth)
                                    utilRoot.startDay = utilRoot.startDay < maxD ? utilRoot.startDay + 1 : 1
                                }
                                onDecrement: {
                                    var maxD = utilRoot.daysInMonth(utilRoot.startYear, utilRoot.startMonth)
                                    utilRoot.startDay = utilRoot.startDay > 1 ? utilRoot.startDay - 1 : maxD
                                }
                                minWidth: 36
                            }
                        }
                    }
                }

                // End date
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: endPickerCol.implicitHeight + 20
                    radius: 6; color: "#f9fafb"
                    border.color: "#e5e7eb"; border.width: 1

                    ColumnLayout {
                        id: endPickerCol
                        anchors { left: parent.left; right: parent.right
                                  top: parent.top; margins: 12 }
                        spacing: 6

                        Label {
                            text: "To"
                            font.pixelSize: 11; color: "#9ca3af"; font.bold: true
                            font.capitalization: Font.AllUppercase
                        }

                        RowLayout {
                            spacing: 4
                            SpinnerField {
                                value: utilRoot.endYear
                                displayText: "" + utilRoot.endYear
                                onIncrement: utilRoot.endYear++
                                onDecrement: if (utilRoot.endYear > 2000) utilRoot.endYear--
                                minWidth: 52
                            }
                            Label { text: "-"; color: "#9ca3af"; font.pixelSize: 14 }
                            SpinnerField {
                                value: utilRoot.endMonth
                                displayText: utilRoot.monthNames[utilRoot.endMonth - 1]
                                onIncrement: {
                                    if (utilRoot.endMonth < 12) utilRoot.endMonth++
                                    else { utilRoot.endMonth = 1; utilRoot.endYear++ }
                                    utilRoot.endDay = utilRoot.clampDay(utilRoot.endYear, utilRoot.endMonth, utilRoot.endDay)
                                }
                                onDecrement: {
                                    if (utilRoot.endMonth > 1) utilRoot.endMonth--
                                    else { utilRoot.endMonth = 12; utilRoot.endYear-- }
                                    utilRoot.endDay = utilRoot.clampDay(utilRoot.endYear, utilRoot.endMonth, utilRoot.endDay)
                                }
                                minWidth: 44
                            }
                            Label { text: "-"; color: "#9ca3af"; font.pixelSize: 14 }
                            SpinnerField {
                                value: utilRoot.endDay
                                displayText: utilRoot.pad2(utilRoot.endDay)
                                onIncrement: {
                                    var maxD = utilRoot.daysInMonth(utilRoot.endYear, utilRoot.endMonth)
                                    utilRoot.endDay = utilRoot.endDay < maxD ? utilRoot.endDay + 1 : 1
                                }
                                onDecrement: {
                                    var maxD = utilRoot.daysInMonth(utilRoot.endYear, utilRoot.endMonth)
                                    utilRoot.endDay = utilRoot.endDay > 1 ? utilRoot.endDay - 1 : maxD
                                }
                                minWidth: 36
                            }
                        }
                    }
                }
            }

            // ── Standard Hours ──────────────────────────────────────
            Label {
                text: "Standard Hours"
                font.pixelSize: 15; font.bold: true; color: "#374151"
                Layout.bottomMargin: 8
            }
            RowLayout {
                spacing: 8
                Layout.bottomMargin: 20

                Label { text: "Hours per working day:"; font.pixelSize: 13; color: "#6b7280" }

                Rectangle {
                    height: 36; radius: 4
                    color: "#f9fafb"; border.color: "#e5e7eb"; border.width: 1
                    implicitWidth: hpdRow.implicitWidth + 8

                    RowLayout {
                        id: hpdRow
                        anchors.centerIn: parent
                        spacing: 4

                        Rectangle {
                            width: 24; height: 24; radius: 4
                            color: hpdMinusMa.containsMouse ? "#e5e7eb" : "transparent"
                            Label { anchors.centerIn: parent; text: "−"; font.pixelSize: 16; color: "#374151" }
                            MouseArea {
                                id: hpdMinusMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (utilRoot.hoursPerDay > 1) utilRoot.hoursPerDay--
                            }
                        }
                        Label {
                            text: utilRoot.hoursPerDay
                            font.pixelSize: 15; font.bold: true; color: "#1f2937"
                            Layout.preferredWidth: 24; horizontalAlignment: Text.AlignHCenter
                        }
                        Rectangle {
                            width: 24; height: 24; radius: 4
                            color: hpdPlusMa.containsMouse ? "#e5e7eb" : "transparent"
                            Label { anchors.centerIn: parent; text: "+"; font.pixelSize: 16; color: "#374151" }
                            MouseArea {
                                id: hpdPlusMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (utilRoot.hoursPerDay < 24) utilRoot.hoursPerDay++
                            }
                        }
                    }
                }
            }

            // ── Holidays ────────────────────────────────────────────
            Label {
                text: "Holidays (Optional)"
                font.pixelSize: 15; font.bold: true; color: "#374151"
                Layout.bottomMargin: 4
            }
            Label {
                text: "Add any public or personal holidays within the date range."
                font.pixelSize: 12; color: "#9ca3af"
                Layout.bottomMargin: 8
            }

            RowLayout {
                spacing: 8
                Layout.bottomMargin: 4

                Rectangle {
                    Layout.fillWidth: true; height: 36; radius: 4
                    color: "#f9fafb"; border.color: holidayInput.activeFocus ? "#93c5fd" : "#e5e7eb"; border.width: 1

                    TextInput {
                        id: holidayInput
                        anchors { fill: parent; margins: 10 }
                        font.pixelSize: 13; color: "#1f2937"
                        verticalAlignment: TextInput.AlignVCenter
                        onAccepted: utilRoot.addHoliday()

                        Text {
                            text: "YYYY-MM-DD"
                            color: "#d1d5db"; font.pixelSize: 13
                            visible: !holidayInput.text
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Rectangle {
                    height: 36; radius: 4
                    implicitWidth: addHlLbl.implicitWidth + 24
                    color: addHlMa.containsMouse ? "#374151" : "#1f2937"
                    Label {
                        id: addHlLbl; anchors.centerIn: parent
                        text: "Add"; font.pixelSize: 13; color: "white"
                    }
                    MouseArea {
                        id: addHlMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: utilRoot.addHoliday()
                    }
                }
            }

            Label {
                id: holidayInputError
                text: ""; font.pixelSize: 12; color: "#ef4444"
                visible: text !== ""
                Layout.bottomMargin: 4
            }

            // Holiday list
            Repeater {
                model: utilRoot.holidayList
                RowLayout {
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 8
                    Layout.bottomMargin: 4

                    Label {
                        text: "\u2022 " + modelData
                        font.pixelSize: 13; color: "#374151"
                        Layout.fillWidth: true
                    }
                    Label {
                        text: "\u00d7"
                        font.pixelSize: 14; color: hlRemoveMa.containsMouse ? "#ef4444" : "#9ca3af"
                        MouseArea {
                            id: hlRemoveMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: utilRoot.removeHoliday(modelData)
                        }
                    }
                }
            }

            Item { implicitHeight: utilRoot.holidayList.length > 0 ? 12 : 16 }

            // ── Error message ───────────────────────────────────────
            Label {
                id: errorLabel
                text: ""; font.pixelSize: 13; color: "#ef4444"
                visible: text !== ""
                Layout.bottomMargin: 8
                wrapMode: Text.WordWrap; Layout.fillWidth: true
            }

            // ── Calculate button ────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; height: 42; radius: 6
                color: calcMa.containsMouse ? "#374151" : "#1f2937"
                Layout.bottomMargin: 20

                RowLayout {
                    anchors.centerIn: parent; spacing: 6
                    Label { text: "%"; font.pixelSize: 16; font.bold: true; color: "white" }
                    Label { text: "Calculate Utilization"; font.pixelSize: 14; font.bold: true; color: "white" }
                }
                MouseArea {
                    id: calcMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: utilRoot.calculate()
                }
            }

            // ── Results ─────────────────────────────────────────────
            ColumnLayout {
                visible: utilResult !== null
                Layout.fillWidth: true
                spacing: 12

                // Summary row
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: summaryGrid.implicitHeight + 20
                    radius: 6; color: "#f9fafb"
                    border.color: "#e5e7eb"; border.width: 1

                    Grid {
                        id: summaryGrid
                        anchors { fill: parent; margins: 14 }
                        columns: 2
                        rowSpacing: 6; columnSpacing: 20

                        Label { text: "Billable hours tracked:"; font.pixelSize: 12; color: "#6b7280" }
                        Label {
                            text: utilResult ? (utilResult.billableHours.toFixed(2) + " h") : ""
                            font.pixelSize: 12; font.bold: true; color: "#1f2937"
                        }

                        Label { text: "Total hours tracked:"; font.pixelSize: 12; color: "#6b7280" }
                        Label {
                            text: utilResult ? (utilResult.totalHours.toFixed(2) + " h") : ""
                            font.pixelSize: 12; font.bold: true; color: "#1f2937"
                        }

                        Label { text: "Working days (Mon–Fri):"; font.pixelSize: 12; color: "#6b7280" }
                        Label {
                            text: utilResult ? (utilResult.workingDays + " days") : ""
                            font.pixelSize: 12; font.bold: true; color: "#1f2937"
                        }

                        Label { text: "Standard hours:"; font.pixelSize: 12; color: "#6b7280" }
                        Label {
                            text: utilResult ? (utilResult.standardHours + " h (" + utilResult.workingDays + " days × " + hoursPerDay + "h)") : ""
                            font.pixelSize: 12; font.bold: true; color: "#1f2937"
                        }

                        Label {
                            visible: utilResult ? utilResult.holidayWorkingDays > 0 : false
                            text: "Holidays (working days):"
                            font.pixelSize: 12; color: "#6b7280"
                        }
                        Label {
                            visible: utilResult ? utilResult.holidayWorkingDays > 0 : false
                            text: utilResult ? (utilResult.holidayWorkingDays + " days (" + (utilResult.holidayWorkingDays * hoursPerDay) + "h deducted)") : ""
                            font.pixelSize: 12; font.bold: true; color: "#1f2937"
                        }
                    }
                }

                // Rate cards
                Label {
                    text: "Utilization Rates"
                    font.pixelSize: 15; font.bold: true; color: "#374151"
                }

                // Rate 1: billable / tracked
                RateCard {
                    Layout.fillWidth: true
                    rateLabel: "Billable / Tracked Time"
                    rateSubtitle: "Billable hours as a share of all tracked hours"
                    rateValue: utilResult ? utilRoot.formatPct(utilResult.rate1) : ""
                    isNA: utilResult ? utilResult.rate1 < 0 : false
                    accentColor: "#3b82f6"
                }

                // Rate 2: billable / standard
                RateCard {
                    Layout.fillWidth: true
                    rateLabel: "Billable / Standard Hours"
                    rateSubtitle: "Billable hours as a share of expected working hours (Mon–Fri × " + hoursPerDay + "h)"
                    rateValue: utilResult ? utilRoot.formatPct(utilResult.rate2) : ""
                    isNA: utilResult ? utilResult.rate2 < 0 : false
                    accentColor: "#10b981"
                }

                // Rate 3: billable / standard minus holidays
                RateCard {
                    Layout.fillWidth: true
                    rateLabel: "Billable / Adjusted Hours"
                    rateSubtitle: "Billable hours as a share of standard hours minus holiday hours"
                    rateValue: utilResult ? utilRoot.formatPct(utilResult.rate3) : ""
                    isNA: utilResult ? utilResult.rate3 < 0 : false
                    accentColor: "#8b5cf6"
                    naReason: "No adjusted hours (check holiday count vs working days)"
                }

                Item { implicitHeight: 8 }
            }
        }
    }

    // ── Inline components ─────────────────────────────────────────

    component SpinnerField: Rectangle {
        property int value: 0
        property string displayText: ""
        property int minWidth: 40
        signal increment()
        signal decrement()

        implicitWidth: Math.max(minWidth, spinLabel.implicitWidth + 24)
        height: 32; radius: 4
        color: "#ffffff"; border.color: "#e5e7eb"; border.width: 1

        RowLayout {
            anchors.fill: parent; anchors.margins: 2; spacing: 0

            Label {
                id: spinLabel
                Layout.fillWidth: true
                text: displayText
                font.pixelSize: 13; font.bold: true; color: "#1f2937"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            ColumnLayout {
                spacing: 0; Layout.rightMargin: 2

                Label {
                    text: "▲"; font.pixelSize: 8
                    color: upMa.containsMouse ? "#1f2937" : "#9ca3af"
                    MouseArea {
                        id: upMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: increment()
                    }
                }
                Label {
                    text: "▼"; font.pixelSize: 8
                    color: downMa.containsMouse ? "#1f2937" : "#9ca3af"
                    MouseArea {
                        id: downMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: decrement()
                    }
                }
            }
        }
    }

    component RateCard: Rectangle {
        property string rateLabel: ""
        property string rateSubtitle: ""
        property string rateValue: ""
        property bool isNA: false
        property string accentColor: "#3b82f6"
        property string naReason: "No data available for this range"

        implicitHeight: rateCardCol.implicitHeight + 24
        radius: 6; color: "#ffffff"
        border.color: "#e5e7eb"; border.width: 1

        Rectangle {
            width: 4; height: parent.height - 16
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            radius: 2; color: accentColor
        }

        ColumnLayout {
            id: rateCardCol
            anchors { left: parent.left; right: parent.right; top: parent.top
                      leftMargin: 16; rightMargin: 14; topMargin: 12 }
            spacing: 4

            RowLayout {
                Layout.fillWidth: true; spacing: 10
                Label {
                    text: rateLabel
                    font.pixelSize: 13; font.bold: true; color: "#374151"
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                }
                Label {
                    text: isNA ? "N/A" : rateValue
                    font.pixelSize: 24; font.bold: true
                    color: isNA ? "#9ca3af" : accentColor
                }
            }
            Label {
                text: isNA ? naReason : rateSubtitle
                font.pixelSize: 11; color: "#9ca3af"
                wrapMode: Text.WordWrap; Layout.fillWidth: true
            }
        }
    }
}
