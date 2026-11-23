import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Item {
    id: settingsRoot

    property var archivedProjects: []
    property bool showArchived: false
    property var availableBackups: []
    property bool showBackups: false

    function refreshArchived() {
        archivedProjects = backend.getArchivedProjects()
    }

    function refreshBackups() {
        availableBackups = backend.getAvailableBackups()
    }

    Component.onCompleted: {
        refreshArchived()
        refreshBackups()
    }

    Connections {
        target: backend
        function onArchivedProjectsChanged() { settingsRoot.refreshArchived() }
        function onJsonTransferDone(message, success) {
            toastLabel.text = message
            toast.success = success
            toastAnim.restart()
            if (success) settingsRoot.refreshBackups()
        }
    }

    // ── Toast ─────────────────────────────────────────────────────
    Rectangle {
        id: toast
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        width: toastLabel.implicitWidth + 32
        height: 36; radius: 18
        color: toast.success ? "#0f172a" : "#dc2626"
        opacity: 0; z: 10
        property bool success: true
        Label { id: toastLabel; anchors.centerIn: parent; font.pixelSize: 13; color: "#f8fafc" }
        SequentialAnimation {
            id: toastAnim
            NumberAnimation { target: toast; property: "opacity"; to: 1; duration: 160 }
            PauseAnimation { duration: 2800 }
            NumberAnimation { target: toast; property: "opacity"; to: 0; duration: 300 }
        }
    }

    // ── File dialogs ──────────────────────────────────────────────
    FileDialog {
        id: exportDialog
        title: "Export tracker data"
        fileMode: FileDialog.SaveFile
        nameFilters: ["JSON files (*.json)"]
        defaultSuffix: "json"
        onAccepted: backend.exportJson(selectedFile)
    }

    FileDialog {
        id: importDialog
        title: "Import tracker data"
        fileMode: FileDialog.OpenFile
        nameFilters: ["JSON files (*.json)"]
        onAccepted: importConfirmDialog.open()
        property string pendingFile: ""
        onSelectedFileChanged: pendingFile = selectedFile
    }

    Dialog {
        id: importConfirmDialog
        modal: true; width: 320
        anchors.centerIn: parent
        closePolicy: Popup.NoAutoClose
        background: Rectangle { radius: 8; color: "#ffffff"; border.color: "#e2e8f0"; border.width: 1 }
        contentItem: ColumnLayout {
            spacing: 0
            Label { text: "Replace all data?"; font.pixelSize: 18; font.bold: true; color: "#0f172a"
                    Layout.bottomMargin: 10 }
            Label { text: "This will overwrite all your current projects and history with the imported file. This cannot be undone."
                    font.pixelSize: 13; color: "#64748b"; wrapMode: Text.WordWrap
                    Layout.fillWidth: true; Layout.bottomMargin: 22 }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Rectangle {
                    Layout.fillWidth: true; height: 40; radius: 8
                    color: icancelMa.containsMouse ? "#f1f5f9" : "#ffffff"
                    border.color: "#e2e8f0"; border.width: 1
                    Label { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 14; color: "#64748b" }
                    MouseArea { id: icancelMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor; onClicked: importConfirmDialog.close() }
                }
                Rectangle {
                    Layout.fillWidth: true; height: 40; radius: 8
                    color: iconfirmMa.containsMouse ? "#b91c1c" : "#dc2626"
                    Label { anchors.centerIn: parent; text: "Replace & Import"; font.pixelSize: 14; color: "white" }
                    MouseArea { id: iconfirmMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { importConfirmDialog.close(); backend.importJson(importDialog.pendingFile) } }
                }
            }
        }
    }

    Dialog {
        id: clearConfirmDialog
        title: "Clear History"
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Yes | Dialog.No
        Label { text: "Clear all history? This cannot be undone."; font.pixelSize: 14 }
        onAccepted: backend.clearHistory()
    }

    // ── Main settings page ────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        visible: !settingsRoot.showArchived && !settingsRoot.showBackups

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: settingsCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: settingsCol
                width: parent.width
                spacing: 0

                // Activity prompt
                Label { text: "\"What are you working on?\""; font.pixelSize: 20; font.bold: true
                        color: "#0f172a"; Layout.bottomMargin: 4 }
                Label { text: "When no timer is running and you use your mouse or\nkeyboard, ask what you're working on."
                        font.pixelSize: 14; color: "#64748b"; Layout.bottomMargin: 12 }

                RowLayout {
                    spacing: 8; Layout.bottomMargin: 10
                    Repeater {
                        model: [true, false]
                        Rectangle {
                            required property bool modelData
                            property bool selected: backend.activityPromptEnabled === modelData
                            width: 80; height: 40; radius: 8
                            color: selected ? "#4f46e5" : promptMa.containsMouse ? "#f1f5f9" : "#ffffff"
                            border.color: "#e2e8f0"; border.width: selected ? 0 : 1
                            Label { anchors.centerIn: parent
                                    text: modelData ? "On" : "Off"
                                    font.pixelSize: 14; color: selected ? "#ffffff" : "#64748b" }
                            MouseArea { id: promptMa; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.setActivityPromptEnabled(modelData) }
                        }
                    }
                }
                Label { visible: backend.activityPromptEnabled
                        text: "After \"Not working\" or stopping a timer, wait before asking again:"
                        font.pixelSize: 13; color: "#64748b"; Layout.bottomMargin: 8
                        wrapMode: Text.WordWrap; Layout.fillWidth: true }
                RowLayout {
                    visible: backend.activityPromptEnabled
                    spacing: 8; Layout.bottomMargin: 24
                    Repeater {
                        model: [5, 15, 30, 60]
                        Rectangle {
                            required property int modelData
                            property bool selected: backend.activityPromptSnooze === modelData
                            width: 72; height: 40; radius: 8
                            color: selected ? "#4f46e5" : snoozeMa.containsMouse ? "#f1f5f9" : "#ffffff"
                            border.color: "#e2e8f0"; border.width: selected ? 0 : 1
                            Label { anchors.centerIn: parent
                                    text: modelData === 60 ? "1 hour" : modelData + " min"
                                    font.pixelSize: 14; color: selected ? "#ffffff" : "#64748b" }
                            MouseArea { id: snoozeMa; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.setActivityPromptSnooze(modelData) }
                        }
                    }
                }
                Item { visible: !backend.activityPromptEnabled; Layout.preferredHeight: 14 }

                // Check-in interval
                Label { text: "Check-in Interval"; font.pixelSize: 20; font.bold: true
                        color: "#0f172a"; Layout.bottomMargin: 4 }
                Label { text: "How often should we check if you're\nstill on the same project?"
                        font.pixelSize: 14; color: "#64748b"; Layout.bottomMargin: 12 }

                RowLayout {
                    spacing: 8; Layout.bottomMargin: 24
                    Repeater {
                        model: [15, 30, 60]
                        Rectangle {
                            required property int modelData
                            required property int index
                            property bool selected: backend.checkInInterval === modelData
                            width: 80; height: 40; radius: 8
                            color: selected ? "#4f46e5" : intervalMa.containsMouse ? "#f1f5f9" : "#ffffff"
                            border.color: "#e2e8f0"; border.width: selected ? 0 : 1
                            Label { anchors.centerIn: parent
                                    text: modelData === 60 ? "1 hour" : modelData + " min"
                                    font.pixelSize: 14; color: selected ? "#ffffff" : "#64748b" }
                            MouseArea { id: intervalMa; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.setCheckInInterval(modelData) }
                        }
                    }
                }

                // Idle timeout
                Label { text: "Idle Timeout"; font.pixelSize: 20; font.bold: true
                        color: "#0f172a"; Layout.bottomMargin: 4 }
                Label { text: "Auto-stop the timer after this long with no\nkeyboard or mouse activity, excluding the idle time."
                        font.pixelSize: 14; color: "#64748b"; Layout.bottomMargin: 12 }

                RowLayout {
                    spacing: 8; Layout.bottomMargin: 24
                    Repeater {
                        model: [5, 10, 15]
                        Rectangle {
                            required property int modelData
                            required property int index
                            property bool selected: backend.idleTimeout === modelData
                            width: 80; height: 40; radius: 8
                            color: selected ? "#4f46e5" : idleMa.containsMouse ? "#f1f5f9" : "#ffffff"
                            border.color: "#e2e8f0"; border.width: selected ? 0 : 1
                            Label { anchors.centerIn: parent
                                    text: modelData + " min"
                                    font.pixelSize: 14; color: selected ? "#ffffff" : "#64748b" }
                            MouseArea { id: idleMa; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.setIdleTimeout(modelData) }
                        }
                    }
                }

                // Data section
                Label { text: "Data"; font.pixelSize: 20; font.bold: true
                        color: "#0f172a"; Layout.bottomMargin: 8 }

                Rectangle {
                    Layout.fillWidth: true; height: 40; radius: 8
                    color: exportMa.containsMouse ? "#4338ca" : "#4f46e5"; Layout.bottomMargin: 8
                    RowLayout { anchors.centerIn: parent; spacing: 8
                        Label { text: "\u2B06"; font.pixelSize: 14; color: "#f8fafc" }
                        Label { text: "Export data (.json)"; font.pixelSize: 14; color: "#f8fafc" } }
                    MouseArea { id: exportMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor; onClicked: exportDialog.open() }
                }

                Rectangle {
                    Layout.fillWidth: true; height: 40; radius: 8
                    color: importMa.containsMouse ? "#4338ca" : "#4f46e5"; Layout.bottomMargin: 16
                    RowLayout { anchors.centerIn: parent; spacing: 8
                        Label { text: "\u2B07"; font.pixelSize: 14; color: "#f8fafc" }
                        Label { text: "Import data (.json)"; font.pixelSize: 14; color: "#f8fafc" } }
                    MouseArea { id: importMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor; onClicked: importDialog.open() }
                }

                // Restore backup nav row
                Rectangle {
                    Layout.fillWidth: true; height: 44; radius: 10
                    color: backupsNavMa.containsMouse ? "#f8fafc" : "#ffffff"
                    border.color: "#e2e8f0"; border.width: 1
                    Layout.bottomMargin: 16

                    RowLayout {
                        anchors { fill: parent; margins: 12 }
                        spacing: 8
                        Label {
                            text: "Restore Backup"
                            font.pixelSize: 14; color: "#1e293b"
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            visible: settingsRoot.availableBackups.length > 0
                            implicitWidth: backupsCountLbl.implicitWidth + 12
                            height: 20; radius: 10
                            color: "#e2e8f0"
                            Label { id: backupsCountLbl; anchors.centerIn: parent
                                    text: settingsRoot.availableBackups.length
                                    font.pixelSize: 11; color: "#64748b" }
                        }
                        Label { text: "›"; font.pixelSize: 18; color: "#94a3b8" }
                    }
                    MouseArea {
                        id: backupsNavMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { settingsRoot.refreshBackups(); settingsRoot.showBackups = true }
                    }
                }

                // Archived projects nav row
                Rectangle {
                    Layout.fillWidth: true; height: 44; radius: 10
                    color: archivedNavMa.containsMouse ? "#f8fafc" : "#ffffff"
                    border.color: "#e2e8f0"; border.width: 1
                    Layout.bottomMargin: 16

                    RowLayout {
                        anchors { fill: parent; margins: 12 }
                        spacing: 8
                        Label {
                            text: "Archived Projects"
                            font.pixelSize: 14; color: "#1e293b"
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            visible: settingsRoot.archivedProjects.length > 0
                            implicitWidth: countLbl.implicitWidth + 12
                            height: 20; radius: 10
                            color: "#e2e8f0"
                            Label { id: countLbl; anchors.centerIn: parent
                                    text: settingsRoot.archivedProjects.length
                                    font.pixelSize: 11; color: "#64748b" }
                        }
                        Label { text: "\u203a"; font.pixelSize: 18; color: "#94a3b8" }
                    }
                    MouseArea {
                        id: archivedNavMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsRoot.showArchived = true
                    }
                }

                // Clear history
                Rectangle {
                    width: clearLabel.implicitWidth + 28; height: 40; radius: 8
                    color: clearMa.containsMouse ? "#fee2e2" : "#fff0f0"
                    border.color: "#fecaca"; border.width: 1
                    Label { id: clearLabel; anchors.centerIn: parent; text: "Clear all history"
                            font.pixelSize: 14; color: "#ef4444" }
                    MouseArea { id: clearMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor; onClicked: clearConfirmDialog.open() }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    // ── Archived projects sub-page ────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        visible: settingsRoot.showArchived

        // Back link
        Label {
            text: "\u2190 Back"
            font.pixelSize: 14
            color: archBackMa.containsMouse ? "#0f172a" : "#64748b"
            Layout.bottomMargin: 4
            MouseArea {
                id: archBackMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: settingsRoot.showArchived = false
            }
        }

        Label {
            text: "Archived Projects"
            font.pixelSize: 20; font.bold: true; color: "#0f172a"
            Layout.bottomMargin: 4
        }
        Label {
            text: "Reinstate a project to make it active again in the timer."
            font.pixelSize: 13; color: "#64748b"
            Layout.bottomMargin: 16
        }

        // Empty state
        Label {
            visible: settingsRoot.archivedProjects.length === 0
            text: "No archived projects yet"
            font.pixelSize: 14; color: "#94a3b8"
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 20
        }

        // Archived project list
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: settingsRoot.archivedProjects.length > 0
            contentHeight: archCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: archCol
                width: parent.width
                spacing: 8

                Repeater {
                    model: settingsRoot.archivedProjects

                    Rectangle {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        height: archRow.implicitHeight + 20
                        radius: 10
                        color: "#ffffff"
                        border.color: "#e2e8f0"; border.width: 1

                        RowLayout {
                            id: archRow
                            anchors { left: parent.left; right: parent.right
                                      verticalCenter: parent.verticalCenter; margins: 14 }
                            spacing: 10

                            // Billable badge
                            Rectangle {
                                width: 6; height: 6; radius: 5
                                color: modelData.billable ? "#10b981" : "#94a3b8"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                Label {
                                    text: modelData.name
                                    font.pixelSize: 14; font.bold: true; color: "#1e293b"
                                    elide: Text.ElideRight; Layout.fillWidth: true
                                }
                                Label {
                                    visible: modelData.billingCode !== ""
                                    text: modelData.billingCode
                                    font.pixelSize: 11; color: "#94a3b8"
                                }
                            }

                            Rectangle {
                                implicitWidth: reinstateLbl.implicitWidth + 20
                                height: 34; radius: 8
                                color: reinstateMa.containsMouse ? "#4338ca" : "#4f46e5"
                                Label {
                                    id: reinstateLbl; anchors.centerIn: parent
                                    text: "Reinstate"; font.pixelSize: 13; color: "white"
                                }
                                MouseArea {
                                    id: reinstateMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: backend.reinstateProject(modelData.name)
                                }
                            }
                        }
                    }
                }

                Item { height: 8 }
            }
        }
    }

    // ── Restore backup sub-page ─────────────────────────────────────
    ConfirmRestoreDialog { id: confirmRestoreDialog }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        visible: settingsRoot.showBackups

        // Back link
        Label {
            text: "← Back"
            font.pixelSize: 14
            color: backupsBackMa.containsMouse ? "#0f172a" : "#64748b"
            Layout.bottomMargin: 4
            MouseArea {
                id: backupsBackMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: settingsRoot.showBackups = false
            }
        }

        Label {
            text: "Restore Backup"
            font.pixelSize: 20; font.bold: true; color: "#0f172a"
            Layout.bottomMargin: 4
        }
        Label {
            text: "Restoring replaces all current data. Your current data is snapshotted first, so restoring can itself be undone."
            font.pixelSize: 13; color: "#64748b"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.bottomMargin: 16
        }

        // Empty state
        Label {
            visible: settingsRoot.availableBackups.length === 0
            text: "No backups yet"
            font.pixelSize: 14; color: "#94a3b8"
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 20
        }

        // Backup list
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: settingsRoot.availableBackups.length > 0
            contentHeight: backupsCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: backupsCol
                width: parent.width
                spacing: 8

                Repeater {
                    model: settingsRoot.availableBackups

                    Rectangle {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        height: backupRow.implicitHeight + 20
                        radius: 10
                        color: "#ffffff"
                        border.color: "#e2e8f0"; border.width: 1

                        RowLayout {
                            id: backupRow
                            anchors { left: parent.left; right: parent.right
                                      verticalCenter: parent.verticalCenter; margins: 14 }
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                Label {
                                    text: modelData.label
                                    font.pixelSize: 14; font.bold: true; color: "#1e293b"
                                    elide: Text.ElideRight; Layout.fillWidth: true
                                }
                                Label {
                                    text: modelData.kind === "rolling" ? "Previous save"
                                        : modelData.kind === "daily" ? "Daily snapshot"
                                        : modelData.kind === "pre-import" ? "Safety snapshot"
                                        : "Safety snapshot"
                                    font.pixelSize: 11; color: "#94a3b8"
                                }
                            }

                            Rectangle {
                                implicitWidth: restoreLbl.implicitWidth + 20
                                height: 34; radius: 8
                                color: restoreMa.containsMouse ? "#4338ca" : "#4f46e5"
                                Label {
                                    id: restoreLbl; anchors.centerIn: parent
                                    text: "Restore"; font.pixelSize: 13; color: "white"
                                }
                                MouseArea {
                                    id: restoreMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        confirmRestoreDialog.backupPath = modelData.path
                                        confirmRestoreDialog.backupLabel = modelData.label
                                        confirmRestoreDialog.backupMtime = modelData.mtime
                                        confirmRestoreDialog.open()
                                    }
                                }
                            }
                        }
                    }
                }

                Item { height: 8 }
            }
        }
    }
}
