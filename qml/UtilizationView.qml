import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: utilRoot

    signal back()

    // ── State ─────────────────────────────────────────────────────
    property var utilResult: null
    property real ptoHours: 0

    // Default: start = first day of current month, end = today
    property int startYear:  new Date().getFullYear()
    property int startMonth: new Date().getMonth() + 1
    property int startDay:   1
    property int endYear:    new Date().getFullYear()
    property int endMonth:   new Date().getMonth() + 1
    property int endDay:     new Date().getDate()

    readonly property var monthNames: ["Jan","Feb","Mar","Apr","May","Jun",
                                       "Jul","Aug","Sep","Oct","Nov","Dec"]

    function daysInMonth(y, m) { return new Date(y, m, 0).getDate() }
    function clampDay(y, m, d) { return Math.min(d, daysInMonth(y, m)) }
    function pad2(n) { return n < 10 ? "0" + n : "" + n }
    function startDateStr() { return startYear + "-" + pad2(startMonth) + "-" + pad2(startDay) }
    function endDateStr()   { return endYear   + "-" + pad2(endMonth)   + "-" + pad2(endDay)   }

    function calculate() {
        errorLabel.text = ""
        utilResult = null
        var r = backend.calculateUtilization(startDateStr(), endDateStr(), ptoHours)
        if (r && r.error) { errorLabel.text = r.error } else { utilResult = r }
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

            // FROM card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: fromInner.implicitHeight + 24
                radius: 6; color: "#ffffff"
                border.color: "#e5e7eb"; border.width: 1
                Layout.bottomMargin: 10

                ColumnLayout {
                    id: fromInner
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 12

                    Label {
                        text: "FROM"; font.pixelSize: 11; font.bold: true; color: "#9ca3af"
                        font.capitalization: Font.AllUppercase
                    }

                    // Year row
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Label { text: "Year"; font.pixelSize: 13; color: "#6b7280"; Layout.preferredWidth: 46 }
                        Rectangle {
                            Layout.fillWidth: true; height: 36; radius: 6
                            color: "#f9fafb"; border.color: "#e5e7eb"; border.width: 1
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 4; spacing: 0
                                Label {
                                    Layout.fillWidth: true; text: utilRoot.startYear
                                    font.pixelSize: 14; color: "#1f2937"
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                }
                                ColumnLayout {
                                    spacing: 0
                                    Label { text: "▲"; font.pixelSize: 9; color: sYearUp.containsMouse ? "#1f2937" : "#9ca3af"
                                        MouseArea { id: sYearUp; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: utilRoot.startYear++ } }
                                    Label { text: "▼"; font.pixelSize: 9; color: sYearDown.containsMouse ? "#1f2937" : "#9ca3af"
                                        MouseArea { id: sYearDown; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: if (utilRoot.startYear > 2000) utilRoot.startYear-- } }
                                }
                            }
                        }
                    }

                    // Month grid row
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8; Layout.bottomMargin: 2
                        Label { text: "Month"; font.pixelSize: 13; color: "#6b7280"; Layout.preferredWidth: 46 }
                        Grid {
                            columns: 4; spacing: 4
                            Repeater {
                                model: utilRoot.monthNames
                                Rectangle {
                                    required property string modelData
                                    required property int index
                                    property bool sel: utilRoot.startMonth === index + 1
                                    width: 52; height: 28; radius: 4
                                    color: sel ? "#1f2937" : (sMonthMa.containsMouse ? "#f0f0f0" : "#ffffff")
                                    border.color: sel ? "transparent" : "#e5e7eb"; border.width: 1
                                    Label { anchors.centerIn: parent; text: modelData; font.pixelSize: 12; font.bold: sel
                                            color: sel ? "#ffffff" : "#374151" }
                                    MouseArea { id: sMonthMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: { utilRoot.startMonth = index + 1
                                                             utilRoot.startDay = utilRoot.clampDay(utilRoot.startYear, utilRoot.startMonth, utilRoot.startDay) } }
                                }
                            }
                        }
                    }

                    // Day grid row
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8; Layout.bottomMargin: 2
                        Label { text: "Day"; font.pixelSize: 13; color: "#6b7280"; Layout.preferredWidth: 46 }
                        Grid {
                            columns: 7; spacing: 4
                            Repeater {
                                model: utilRoot.daysInMonth(utilRoot.startYear, utilRoot.startMonth)
                                Rectangle {
                                    required property int index
                                    property int dayNum: index + 1
                                    property bool sel: utilRoot.startDay === dayNum
                                    width: 32; height: 26; radius: 4
                                    color: sel ? "#1f2937" : (sDayMa.containsMouse ? "#f0f0f0" : "#ffffff")
                                    border.color: sel ? "transparent" : "#e5e7eb"; border.width: 1
                                    Label { anchors.centerIn: parent; text: dayNum; font.pixelSize: 12; font.bold: sel
                                            color: sel ? "#ffffff" : "#374151" }
                                    MouseArea { id: sDayMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: utilRoot.startDay = dayNum }
                                }
                            }
                        }
                    }
                }
            }

            // TO card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: toInner.implicitHeight + 24
                radius: 6; color: "#ffffff"
                border.color: "#e5e7eb"; border.width: 1
                Layout.bottomMargin: 20

                ColumnLayout {
                    id: toInner
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 12

                    Label {
                        text: "TO"; font.pixelSize: 11; font.bold: true; color: "#9ca3af"
                        font.capitalization: Font.AllUppercase
                    }

                    // Year row
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Label { text: "Year"; font.pixelSize: 13; color: "#6b7280"; Layout.preferredWidth: 46 }
                        Rectangle {
                            Layout.fillWidth: true; height: 36; radius: 6
                            color: "#f9fafb"; border.color: "#e5e7eb"; border.width: 1
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 4; spacing: 0
                                Label {
                                    Layout.fillWidth: true; text: utilRoot.endYear
                                    font.pixelSize: 14; color: "#1f2937"
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                }
                                ColumnLayout {
                                    spacing: 0
                                    Label { text: "▲"; font.pixelSize: 9; color: eYearUp.containsMouse ? "#1f2937" : "#9ca3af"
                                        MouseArea { id: eYearUp; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: utilRoot.endYear++ } }
                                    Label { text: "▼"; font.pixelSize: 9; color: eYearDown.containsMouse ? "#1f2937" : "#9ca3af"
                                        MouseArea { id: eYearDown; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: if (utilRoot.endYear > 2000) utilRoot.endYear-- } }
                                }
                            }
                        }
                    }

                    // Month grid row
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8; Layout.bottomMargin: 2
                        Label { text: "Month"; font.pixelSize: 13; color: "#6b7280"; Layout.preferredWidth: 46 }
                        Grid {
                            columns: 4; spacing: 4
                            Repeater {
                                model: utilRoot.monthNames
                                Rectangle {
                                    required property string modelData
                                    required property int index
                                    property bool sel: utilRoot.endMonth === index + 1
                                    width: 52; height: 28; radius: 4
                                    color: sel ? "#1f2937" : (eMonthMa.containsMouse ? "#f0f0f0" : "#ffffff")
                                    border.color: sel ? "transparent" : "#e5e7eb"; border.width: 1
                                    Label { anchors.centerIn: parent; text: modelData; font.pixelSize: 12; font.bold: sel
                                            color: sel ? "#ffffff" : "#374151" }
                                    MouseArea { id: eMonthMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: { utilRoot.endMonth = index + 1
                                                             utilRoot.endDay = utilRoot.clampDay(utilRoot.endYear, utilRoot.endMonth, utilRoot.endDay) } }
                                }
                            }
                        }
                    }

                    // Day grid row
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8; Layout.bottomMargin: 2
                        Label { text: "Day"; font.pixelSize: 13; color: "#6b7280"; Layout.preferredWidth: 46 }
                        Grid {
                            columns: 7; spacing: 4
                            Repeater {
                                model: utilRoot.daysInMonth(utilRoot.endYear, utilRoot.endMonth)
                                Rectangle {
                                    required property int index
                                    property int dayNum: index + 1
                                    property bool sel: utilRoot.endDay === dayNum
                                    width: 32; height: 26; radius: 4
                                    color: sel ? "#1f2937" : (eDayMa.containsMouse ? "#f0f0f0" : "#ffffff")
                                    border.color: sel ? "transparent" : "#e5e7eb"; border.width: 1
                                    Label { anchors.centerIn: parent; text: dayNum; font.pixelSize: 12; font.bold: sel
                                            color: sel ? "#ffffff" : "#374151" }
                                    MouseArea { id: eDayMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: utilRoot.endDay = dayNum }
                                }
                            }
                        }
                    }
                }
            }

            // ── PTO / Holiday Hours ─────────────────────────────────
            Label {
                text: "PTO / Holiday Hours"
                font.pixelSize: 15; font.bold: true; color: "#374151"
                Layout.bottomMargin: 4
            }
            Label {
                text: "Total hours to deduct from standard hours (optional)."
                font.pixelSize: 12; color: "#9ca3af"
                Layout.bottomMargin: 10
            }

            RowLayout {
                spacing: 8; Layout.bottomMargin: 20

                Label { text: "Hours to deduct:"; font.pixelSize: 13; color: "#6b7280" }

                Rectangle {
                    height: 36; radius: 4
                    color: "#f9fafb"; border.color: "#e5e7eb"; border.width: 1
                    implicitWidth: ptoRow.implicitWidth + 8

                    RowLayout {
                        id: ptoRow; anchors.centerIn: parent; spacing: 4

                        Rectangle {
                            width: 24; height: 24; radius: 4
                            color: ptoMinusMa.containsMouse ? "#e5e7eb" : "transparent"
                            Label { anchors.centerIn: parent; text: "−"; font.pixelSize: 16; color: "#374151" }
                            MouseArea {
                                id: ptoMinusMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (utilRoot.ptoHours > 0) utilRoot.ptoHours = Math.max(0, utilRoot.ptoHours - 1)
                            }
                        }
                        Label {
                            text: utilRoot.ptoHours % 1 === 0 ? utilRoot.ptoHours + "h" : utilRoot.ptoHours + "h"
                            font.pixelSize: 15; font.bold: true; color: "#1f2937"
                            Layout.preferredWidth: 40; horizontalAlignment: Text.AlignHCenter
                        }
                        Rectangle {
                            width: 24; height: 24; radius: 4
                            color: ptoPlusMa.containsMouse ? "#e5e7eb" : "transparent"
                            Label { anchors.centerIn: parent; text: "+"; font.pixelSize: 16; color: "#374151" }
                            MouseArea {
                                id: ptoPlusMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: utilRoot.ptoHours++
                            }
                        }
                    }
                }
            }

            // ── Error message ───────────────────────────────────────
            Label {
                id: errorLabel
                text: ""; font.pixelSize: 13; color: "#ef4444"
                visible: text !== ""; Layout.bottomMargin: 8
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
                    cursorShape: Qt.PointingHandCursor; onClicked: utilRoot.calculate()
                }
            }

            // ── Results ─────────────────────────────────────────────
            ColumnLayout {
                visible: utilResult !== null
                Layout.fillWidth: true
                spacing: 12

                // Summary card
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: summaryGrid.implicitHeight + 20
                    radius: 6; color: "#f9fafb"
                    border.color: "#e5e7eb"; border.width: 1

                    Grid {
                        id: summaryGrid
                        anchors { fill: parent; margins: 14 }
                        columns: 2; rowSpacing: 6; columnSpacing: 20

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

                        Label { text: "Standard hours (8h/day):"; font.pixelSize: 12; color: "#6b7280" }
                        Label {
                            text: utilResult ? (utilResult.standardHours + " h") : ""
                            font.pixelSize: 12; font.bold: true; color: "#1f2937"
                        }

                        Label {
                            visible: utilResult ? utilResult.ptoHours > 0 : false
                            text: "PTO / holiday hours deducted:"
                            font.pixelSize: 12; color: "#6b7280"
                        }
                        Label {
                            visible: utilResult ? utilResult.ptoHours > 0 : false
                            text: utilResult ? (utilResult.ptoHours + " h") : ""
                            font.pixelSize: 12; font.bold: true; color: "#1f2937"
                        }
                    }
                }

                Label {
                    text: "Utilization Rates"
                    font.pixelSize: 15; font.bold: true; color: "#374151"
                }

                RateCard {
                    Layout.fillWidth: true
                    rateLabel: "Billable / Tracked Time"
                    rateSubtitle: "Billable hours as a share of all tracked hours"
                    rateValue: utilResult ? utilRoot.formatPct(utilResult.rate1) : ""
                    isNA: utilResult ? utilResult.rate1 < 0 : false
                    accentColor: "#3b82f6"
                }

                RateCard {
                    Layout.fillWidth: true
                    rateLabel: "Billable / Standard Hours"
                    rateSubtitle: "Billable hours as a share of expected working hours (Mon–Fri × 8h)"
                    rateValue: utilResult ? utilRoot.formatPct(utilResult.rate2) : ""
                    isNA: utilResult ? utilResult.rate2 < 0 : false
                    accentColor: "#10b981"
                }

                RateCard {
                    Layout.fillWidth: true
                    rateLabel: "Billable / Adjusted Hours"
                    rateSubtitle: utilResult && utilResult.ptoHours > 0
                                  ? "Billable hours as a share of standard hours minus " + utilResult.ptoHours + "h PTO/holiday"
                                  : "Set PTO/holiday hours above to see an adjusted rate"
                    rateValue: utilResult ? utilRoot.formatPct(utilResult.rate3) : ""
                    isNA: utilResult ? utilResult.rate3 < 0 : false
                    accentColor: "#8b5cf6"
                    naReason: "No adjusted hours — PTO/holiday hours equal or exceed standard hours"
                }

                Item { implicitHeight: 8 }
            }
        }
    }

    // ── RateCard component ────────────────────────────────────────
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
                    text: rateLabel; font.pixelSize: 13; font.bold: true; color: "#374151"
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
