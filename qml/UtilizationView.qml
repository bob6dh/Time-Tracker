import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: utilRoot

    signal back()

    // ── State ─────────────────────────────────────────────────────
    property var utilResult: null
    property real ptoHours: 0
    property real holidayHours: 0

    function calculate() {
        errorLabel.text = ""
        utilResult = null
        var r = backend.calculateUtilization(fromPicker.dateStr(), toPicker.dateStr(), ptoHours, holidayHours)
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

                    DatePicker {
                        id: fromPicker
                        Layout.fillWidth: true
                        day: 1   // default: first day of the current month
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

                    DatePicker {
                        id: toPicker
                        Layout.fillWidth: true
                        // defaults to today
                    }
                }
            }

            // ── Deductions ──────────────────────────────────────────
            Label {
                text: "Deductions (Optional)"
                font.pixelSize: 15; font.bold: true; color: "#374151"
                Layout.bottomMargin: 4
            }
            Label {
                text: "Hours to deduct from standard hours when calculating the adjusted rate."
                font.pixelSize: 12; color: "#9ca3af"
                Layout.bottomMargin: 10
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 12; Layout.bottomMargin: 20

                // PTO Hours
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4

                    Label { text: "PTO Hours"; font.pixelSize: 13; color: "#6b7280" }
                    Rectangle {
                        Layout.fillWidth: true; height: 36; radius: 4
                        color: "#f9fafb"
                        border.color: ptoInput.activeFocus ? "#93c5fd" : "#e5e7eb"
                        border.width: 1

                        TextInput {
                            id: ptoInput
                            anchors { fill: parent; margins: 10 }
                            font.pixelSize: 14; color: "#1f2937"
                            verticalAlignment: TextInput.AlignVCenter
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            text: utilRoot.ptoHours > 0 ? utilRoot.ptoHours : ""
                            onTextChanged: {
                                var v = parseFloat(text)
                                utilRoot.ptoHours = (text === "" || isNaN(v) || v < 0) ? 0 : v
                            }
                            Text {
                                text: "0"; color: "#d1d5db"; font.pixelSize: 14
                                visible: !ptoInput.text
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                // Holiday Hours
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4

                    Label { text: "Holiday Hours"; font.pixelSize: 13; color: "#6b7280" }
                    Rectangle {
                        Layout.fillWidth: true; height: 36; radius: 4
                        color: "#f9fafb"
                        border.color: holInput.activeFocus ? "#93c5fd" : "#e5e7eb"
                        border.width: 1

                        TextInput {
                            id: holInput
                            anchors { fill: parent; margins: 10 }
                            font.pixelSize: 14; color: "#1f2937"
                            verticalAlignment: TextInput.AlignVCenter
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            text: utilRoot.holidayHours > 0 ? utilRoot.holidayHours : ""
                            onTextChanged: {
                                var v = parseFloat(text)
                                utilRoot.holidayHours = (text === "" || isNaN(v) || v < 0) ? 0 : v
                            }
                            Text {
                                text: "0"; color: "#d1d5db"; font.pixelSize: 14
                                visible: !holInput.text
                                anchors.verticalCenter: parent.verticalCenter
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
                            text: "PTO hours deducted:"
                            font.pixelSize: 12; color: "#6b7280"
                        }
                        Label {
                            visible: utilResult ? utilResult.ptoHours > 0 : false
                            text: utilResult ? (utilResult.ptoHours + " h") : ""
                            font.pixelSize: 12; font.bold: true; color: "#1f2937"
                        }

                        Label {
                            visible: utilResult ? utilResult.holidayHours > 0 : false
                            text: "Holiday hours deducted:"
                            font.pixelSize: 12; color: "#6b7280"
                        }
                        Label {
                            visible: utilResult ? utilResult.holidayHours > 0 : false
                            text: utilResult ? (utilResult.holidayHours + " h") : ""
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
                    rateSubtitle: {
                        if (!utilResult) return ""
                        var total = (utilResult.ptoHours || 0) + (utilResult.holidayHours || 0)
                        if (total <= 0) return "Enter PTO or holiday hours above to see an adjusted rate"
                        var parts = []
                        if (utilResult.ptoHours > 0) parts.push(utilResult.ptoHours + "h PTO")
                        if (utilResult.holidayHours > 0) parts.push(utilResult.holidayHours + "h holidays")
                        return "Billable hours as a share of standard hours minus " + parts.join(" and ")
                    }
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
