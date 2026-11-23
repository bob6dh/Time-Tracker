import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore

Item {
    id: reportView

    property bool showUtilization: false

    Component.onCompleted: backend.refreshReport()

    // ── Toast notification ───────────────────────────────────────────
    Rectangle {
        id: toast
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        width: toastLabel.implicitWidth + 32
        height: 40
        radius: 20
        color: toastSuccess ? "#059669" : "#ef4444"
        opacity: 0
        z: 10

        property bool toastSuccess: true

        Label {
            id: toastLabel
            anchors.centerIn: parent
            font.pixelSize: 13
            font.bold: true
            color: "white"
        }

        function show(message, success) {
            toastLabel.text = message
            toast.toastSuccess = success
            showAnim.restart()
        }

        SequentialAnimation {
            id: showAnim
            NumberAnimation { target: toast; property: "opacity"; to: 1; duration: 180 }
            PauseAnimation { duration: 3000 }
            NumberAnimation { target: toast; property: "opacity"; to: 0; duration: 400 }
        }
    }

    // ── Export dialog ────────────────────────────────────────────────
    Dialog {
        id: exportDialog
        anchors.centerIn: parent
        modal: true
        width: 340
        padding: 0
        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

        property int selectedYear: new Date().getFullYear()
        property int selectedMonth: new Date().getMonth() + 1
        property string selectedFormat: "xlsx"   // "xlsx" or "csv"

        function yearMonth() {
            return selectedYear + "-" + (selectedMonth < 10 ? "0" + selectedMonth : selectedMonth)
        }

        background: Rectangle {
            radius: 10
            color: "#ffffff"
            border.color: "#e2e8f0"
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 0

            // Header
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: exportHeaderCol.implicitHeight + 28
                color: "#f8fafc"
                radius: 10

                // Square off bottom corners
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 10; color: "#f8fafc"
                }

                ColumnLayout {
                    id: exportHeaderCol
                    anchors { left: parent.left; right: parent.right; top: parent.top
                              margins: 20; topMargin: 20 }
                    spacing: 3

                    Label {
                        text: "Export Report"
                        font.pixelSize: 18; font.bold: true; color: "#0f172a"
                    }
                    Label {
                        text: "Choose a month and format to export."
                        font.pixelSize: 13; color: "#64748b"
                    }
                }
            }

            // Body
            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 20
                Layout.topMargin: 18
                spacing: 14

                // Year row
                RowLayout {
                    Layout.fillWidth: true; spacing: 10

                    Label {
                        text: "Year"; font.pixelSize: 13; color: "#64748b"
                        Layout.preferredWidth: 46
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 36; radius: 10
                        color: "#ffffff"; border.color: "#e2e8f0"; border.width: 1

                        RowLayout {
                            anchors.fill: parent; anchors.margins: 4; spacing: 0

                            Label {
                                Layout.fillWidth: true
                                text: exportDialog.selectedYear
                                font.pixelSize: 14; font.bold: true; color: "#0f172a"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            ColumnLayout {
                                spacing: 0
                                Label {
                                    text: "▲"; font.pixelSize: 9
                                    color: yearUpMa.containsMouse ? "#4f46e5" : "#94a3b8"
                                    MouseArea {
                                        id: yearUpMa; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: exportDialog.selectedYear++
                                    }
                                }
                                Label {
                                    text: "▼"; font.pixelSize: 9
                                    color: yearDownMa.containsMouse ? "#4f46e5" : "#94a3b8"
                                    MouseArea {
                                        id: yearDownMa; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (exportDialog.selectedYear > 2000) exportDialog.selectedYear--
                                    }
                                }
                            }
                        }
                    }
                }

                // Month grid
                RowLayout {
                    Layout.fillWidth: true; spacing: 10

                    Label {
                        text: "Month"; font.pixelSize: 13; color: "#64748b"
                        Layout.preferredWidth: 46
                    }

                    Grid {
                        columns: 4; spacing: 5

                        Repeater {
                            model: ["Jan","Feb","Mar","Apr","May","Jun",
                                    "Jul","Aug","Sep","Oct","Nov","Dec"]

                            Rectangle {
                                required property string modelData
                                required property int index
                                property bool selected: exportDialog.selectedMonth === index + 1

                                width: 52; height: 30; radius: 10
                                color: selected ? "#e0e7ff" : (monthMa.containsMouse ? "#f5f7ff" : "#ffffff")
                                border.color: selected ? "#c7d2fe" : "#e2e8f0"
                                border.width: 1

                                Label {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.pixelSize: 12; font.bold: selected
                                    color: selected ? "#4338ca" : "#1e293b"
                                }

                                MouseArea {
                                    id: monthMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: exportDialog.selectedMonth = index + 1
                                }
                            }
                        }
                    }
                }

                // Format row
                RowLayout {
                    Layout.fillWidth: true; spacing: 10

                    Label {
                        text: "Format"; font.pixelSize: 13; color: "#64748b"
                        Layout.preferredWidth: 46
                    }

                    Row {
                        spacing: 5

                        Repeater {
                            model: [
                                { key: "xlsx", label: "Excel (.xlsx)" },
                                { key: "csv",  label: "CSV (.csv)" }
                            ]

                            Rectangle {
                                required property var modelData
                                property bool selected: exportDialog.selectedFormat === modelData.key

                                width: formatLbl.implicitWidth + 20; height: 30; radius: 10
                                color: selected ? "#e0e7ff" : (formatMa.containsMouse ? "#f5f7ff" : "#ffffff")
                                border.color: selected ? "#c7d2fe" : "#e2e8f0"
                                border.width: 1

                                Label {
                                    id: formatLbl
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.pixelSize: 12; font.bold: selected
                                    color: selected ? "#4338ca" : "#1e293b"
                                }

                                MouseArea {
                                    id: formatMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: exportDialog.selectedFormat = modelData.key
                                }
                            }
                        }
                    }
                }

                // Buttons
                RowLayout {
                    Layout.fillWidth: true; Layout.topMargin: 4; spacing: 8

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitWidth: cancelLbl.implicitWidth + 28; height: 38; radius: 10
                        color: cancelMa.containsMouse ? "#f1f5f9" : "#ffffff"
                        border.color: "#e2e8f0"; border.width: 1

                        Label {
                            id: cancelLbl; anchors.centerIn: parent
                            text: "Cancel"; font.pixelSize: 13; color: "#64748b"
                        }
                        MouseArea {
                            id: cancelMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: exportDialog.close()
                        }
                    }

                    Rectangle {
                        implicitWidth: exportLbl.implicitWidth + 28; height: 38; radius: 10
                        color: exportBtnMa.containsMouse ? "#4338ca" : "#4f46e5"

                        Label {
                            id: exportLbl; anchors.centerIn: parent
                            text: "Choose File…"; font.pixelSize: 13; font.bold: true; color: "white"
                        }
                        MouseArea {
                            id: exportBtnMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var ext = exportDialog.selectedFormat
                                fileDialog.nameFilters = ext === "csv" ? ["CSV files (*.csv)"] : ["Excel files (*.xlsx)"]
                                fileDialog.defaultSuffix = ext
                                var home = StandardPaths.writableLocation(StandardPaths.HomeLocation)
                                fileDialog.currentFolder = home
                                fileDialog.currentFile = home + "/report-" + exportDialog.yearMonth() + "." + ext
                                fileDialog.open()
                            }
                        }
                    }
                }
            }
        }
    }

    // ── File save dialog ─────────────────────────────────────────────
    FileDialog {
        id: fileDialog
        title: "Save Report"
        fileMode: FileDialog.SaveFile
        nameFilters: ["Excel files (*.xlsx)"]
        defaultSuffix: "xlsx"

        onAccepted: {
            exportDialog.close()
            if (exportDialog.selectedFormat === "csv") {
                backend.exportMonthlyReportCsv(exportDialog.yearMonth(), selectedFile.toString())
            } else {
                backend.exportMonthlyReport(exportDialog.yearMonth(), selectedFile.toString())
            }
        }
    }

    // ── Listen for export result ─────────────────────────────────────
    Connections {
        target: backend
        function onExportDone(message, success) {
            toast.show(message, success)
        }
    }

    // ── Utilization sub-page ─────────────────────────────────────────
    UtilizationView {
        anchors.fill: parent
        visible: reportView.showUtilization
        onBack: reportView.showUtilization = false
    }

    // ── Main layout ──────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        visible: !reportView.showUtilization

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: reportCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: reportCol
                width: parent.width
                spacing: 8

                // Period selector (Day | Week | Month)
                RowLayout {
                    spacing: 6
                    Layout.bottomMargin: 4

                    Repeater {
                        model: ["day", "week", "month"]

                        Rectangle {
                            required property string modelData
                            required property int index
                            width: periodLbl.implicitWidth + 28
                            height: periodLbl.implicitHeight + 10
                            radius: 8
                            color: backend.reportPeriod === modelData ? "#0f172a" : "#ffffff"
                            border.color: "#e2e8f0"
                            border.width: backend.reportPeriod === modelData ? 0 : 1

                            Label {
                                id: periodLbl
                                anchors.centerIn: parent
                                text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                font.pixelSize: 14
                                color: backend.reportPeriod === modelData ? "#ffffff" : "#64748b"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: backend.setReportPeriod(modelData)
                            }
                        }
                    }
                }

                // Navigation (< label >)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        width: 36
                        height: 36
                        radius: 8
                        color: prevMa.containsMouse ? "#f1f5f9" : "#ffffff"
                        border.color: "#e2e8f0"
                        border.width: 1

                        Label {
                            anchors.centerIn: parent
                            text: "\u2190"
                            font.pixelSize: 16
                            color: "#64748b"
                        }
                        MouseArea {
                            id: prevMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.reportPrev()
                        }
                    }

                    Label {
                        text: backend.reportLabel
                        font.pixelSize: 15
                        font.bold: true
                        color: "#0f172a"
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        width: 36
                        height: 36
                        radius: 8
                        color: nextMa.containsMouse ? "#f1f5f9" : "#ffffff"
                        border.color: "#e2e8f0"
                        border.width: 1

                        Label {
                            anchors.centerIn: parent
                            text: "\u2192"
                            font.pixelSize: 16
                            color: "#64748b"
                        }
                        MouseArea {
                            id: nextMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.reportNext()
                        }
                    }
                }

                // Total time card
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: totalCol.implicitHeight + 24
                    radius: 10
                    color: "#eef2ff"
                    border.color: "#c7d2fe"
                    border.width: 1

                    ColumnLayout {
                        id: totalCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 2

                        Label {
                            text: "Total Time"
                            font.pixelSize: 12
                            color: "#64748b"
                        }
                        Label {
                            text: backend.reportTotal
                            font.pixelSize: 28
                            font.features: { "tnum": 1 }
                            font.weight: Font.DemiBold
                            font.bold: true
                            color: "#0f172a"
                        }
                    }
                }

                // Empty state
                Label {
                    text: "No time tracked for this period"
                    font.pixelSize: 14
                    color: "#94a3b8"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 20
                    visible: reportRepeater.count === 0
                }

                // Project breakdown
                Repeater {
                    id: reportRepeater
                    model: backend.reportModel

                    Rectangle {
                        required property string project
                        required property string time
                        required property int seconds
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: reportItemCol.implicitHeight + 24
                        radius: 10
                        color: "#ffffff"
                        border.color: "#e2e8f0"
                        border.width: 1

                        ColumnLayout {
                            id: reportItemCol
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true

                                Label {
                                    text: project
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: "#0f172a"
                                    Layout.fillWidth: true
                                }
                                Label {
                                    text: time
                                    font.pixelSize: 14
                                    font.features: { "tnum": 1 }
                                    font.weight: Font.DemiBold
                                    color: "#64748b"
                                }
                            }

                            // Progress bar
                            Rectangle {
                                Layout.fillWidth: true
                                height: 6
                                radius: 5
                                color: "#f1f5f9"

                                Rectangle {
                                    width: {
                                        var total = backend.reportTotalSeconds
                                        if (total <= 0) return 0
                                        return parent.width * (seconds / total)
                                    }
                                    height: parent.height
                                    radius: 5
                                    color: {
                                        var colors = ["#6366f1", "#10b981", "#f59e0b", "#ef4444", "#8b5cf6", "#ec4899"]
                                        var i = (index !== undefined && index >= 0) ? index : 0
                                        return colors[i % colors.length]
                                    }
                                }
                            }
                        }
                    }
                }

                // Export button
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 10
                    Layout.topMargin: 4
                    color: xlsxMa.containsMouse ? "#1e293b" : "#0f172a"

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Label {
                            text: "↓"
                            font.pixelSize: 16
                            font.bold: true
                            color: "white"
                        }
                        Label {
                            text: "Export Report"
                            font.pixelSize: 14
                            font.bold: true
                            color: "white"
                        }
                    }

                    MouseArea {
                        id: xlsxMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: exportDialog.open()
                    }
                }

                // Utilization Rate button
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 10
                    Layout.topMargin: 4
                    color: utilMa.containsMouse ? "#4338ca" : "#4f46e5"

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Label {
                            text: "%"
                            font.pixelSize: 16
                            font.bold: true
                            color: "white"
                        }
                        Label {
                            text: "Utilization Rate"
                            font.pixelSize: 14
                            font.bold: true
                            color: "white"
                        }
                    }

                    MouseArea {
                        id: utilMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: reportView.showUtilization = true
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
