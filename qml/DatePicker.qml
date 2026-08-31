import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Reusable year/month/day spinner picker. Owns its own year/month/day state
// (defaulting to today) — callers read `dateStr()` (or the individual
// properties) when they need the value, rather than relying on a live binding
// back to a caller-owned property.
ColumnLayout {
    id: datePicker
    spacing: 12

    property int year:  new Date().getFullYear()
    property int month: new Date().getMonth() + 1
    property int day:   new Date().getDate()
    property int minYear: 2000

    readonly property var monthNames: ["Jan","Feb","Mar","Apr","May","Jun",
                                       "Jul","Aug","Sep","Oct","Nov","Dec"]

    function daysInMonth(y, m) { return new Date(y, m, 0).getDate() }
    function clampDay(y, m, d) { return Math.min(d, daysInMonth(y, m)) }
    function pad2(n) { return n < 10 ? "0" + n : "" + n }
    function dateStr() { return year + "-" + pad2(month) + "-" + pad2(day) }

    // Set year/month/day from an "YYYY-MM-DD" string; no-op if blank/invalid.
    function setFromString(s) {
        if (!s) return
        var parts = s.split("-")
        if (parts.length !== 3) return
        var y = parseInt(parts[0], 10), m = parseInt(parts[1], 10), d = parseInt(parts[2], 10)
        if (isNaN(y) || isNaN(m) || isNaN(d)) return
        year = y; month = m; day = clampDay(y, m, d)
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
                    Layout.fillWidth: true; text: datePicker.year
                    font.pixelSize: 14; color: "#1f2937"
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                ColumnLayout {
                    spacing: 0
                    Label { text: "▲"; font.pixelSize: 9; color: yearUpMa.containsMouse ? "#1f2937" : "#9ca3af"
                        MouseArea { id: yearUpMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: datePicker.year++ } }
                    Label { text: "▼"; font.pixelSize: 9; color: yearDownMa.containsMouse ? "#1f2937" : "#9ca3af"
                        MouseArea { id: yearDownMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: if (datePicker.year > datePicker.minYear) datePicker.year-- } }
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
                model: datePicker.monthNames
                Rectangle {
                    required property string modelData
                    required property int index
                    property bool sel: datePicker.month === index + 1
                    width: 52; height: 28; radius: 4
                    color: sel ? "#1f2937" : (monthMa.containsMouse ? "#f0f0f0" : "#ffffff")
                    border.color: sel ? "transparent" : "#e5e7eb"; border.width: 1
                    Label { anchors.centerIn: parent; text: modelData; font.pixelSize: 12; font.bold: sel
                            color: sel ? "#ffffff" : "#374151" }
                    MouseArea { id: monthMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { datePicker.month = index + 1
                                             datePicker.day = datePicker.clampDay(datePicker.year, datePicker.month, datePicker.day) } }
                }
            }
        }
    }

    // Day grid row
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        Label { text: "Day"; font.pixelSize: 13; color: "#6b7280"; Layout.preferredWidth: 46 }
        Grid {
            columns: 7; spacing: 4
            Repeater {
                model: datePicker.daysInMonth(datePicker.year, datePicker.month)
                Rectangle {
                    required property int index
                    property int dayNum: index + 1
                    property bool sel: datePicker.day === dayNum
                    width: 32; height: 26; radius: 4
                    color: sel ? "#1f2937" : (dayMa.containsMouse ? "#f0f0f0" : "#ffffff")
                    border.color: sel ? "transparent" : "#e5e7eb"; border.width: 1
                    Label { anchors.centerIn: parent; text: dayNum; font.pixelSize: 12; font.bold: sel
                            color: sel ? "#ffffff" : "#374151" }
                    MouseArea { id: dayMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: datePicker.day = dayNum }
                }
            }
        }
    }
}
