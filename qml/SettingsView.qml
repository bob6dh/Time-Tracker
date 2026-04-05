import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Item {
    id: settingsRoot

    property var archivedProjects: []

    function refreshArchived() {
        archivedProjects = backend.getArchivedProjects()
    }

    Component.onCompleted: refreshArchived()

    Connections {
        target: backend
        function onArchivedProjectsChanged() { settingsRoot.refreshArchived() }
    }

    // ── Toast notification ────────────────────────────────────────
    Rectangle {
        id: toast
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        width: toastLabel.implicitWidth + 32
        height: 36
        radius: 18
        color: toast.success ? "#1f2937" : "#dc2626"
        opacity: 0
        z: 10

        property bool success: true

        Label {
            id: toastLabel
            anchors.centerIn: parent
            font.pixelSize: 13
            color: "#f9fafb"
        }

        SequentialAnimation {
            id: toastAnim
            NumberAnimation { target: toast; property: "opacity"; to: 1; duration: 160 }
            PauseAnimation { duration: 2800 }
            NumberAnimation { target: toast; property: "opacity"; to: 0; duration: 300 }
        }
    }

    Connections {
        target: backend
        function onJsonTransferDone(message, success) {
            toastLabel.text = message
            toast.success = success
            toastAnim.restart()
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
        title: ""
        modal: true
        width: 320
        anchors.centerIn: parent
        closePolicy: Popup.NoAutoClose

        background: Rectangle {
            radius: 8
            color: "#ffffff"
            border.color: "#e5e7eb"
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 0

            Label {
                text: "Replace all data?"
                font.pixelSize: 18
                font.bold: true
                color: "#1f2937"
                Layout.bottomMargin: 10
            }
            Label {
                text: "This will overwrite all your current projects and history with the imported file. This cannot be undone."
                font.pixelSize: 13
                color: "#6b7280"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.bottomMargin: 22
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    height: 40; radius: 4
                    color: icancelMa.containsMouse ? "#f3f4f6" : "#ffffff"
                    border.color: "#e5e7eb"; border.width: 1
                    Label {
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.pixelSize: 14
                        color: "#6b7280"
                    }
                    MouseArea {
                        id: icancelMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: importConfirmDialog.close()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 40; radius: 4
                    color: iconfirmMa.containsMouse ? "#b91c1c" : "#dc2626"
                    Label {
                        anchors.centerIn: parent
                        text: "Replace & Import"
                        font.pixelSize: 14
                        color: "white"
                    }
                    MouseArea {
                        id: iconfirmMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            importConfirmDialog.close()
                            backend.importJson(importDialog.pendingFile)
                        }
                    }
                }
            }
        }
    }

    // ── Main layout ───────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

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

                // ── Check-in interval ─────────────────────────────
                Label {
                    text: "Check-in Interval"
                    font.pixelSize: 20
                    font.bold: true
                    color: "#1f2937"
                    Layout.bottomMargin: 4
                }
                Label {
                    text: "How often should we check if you're\nstill on the same project?"
                    font.pixelSize: 14
                    color: "#6b7280"
                    Layout.bottomMargin: 12
                }

                RowLayout {
                    spacing: 8
                    Layout.bottomMargin: 24

                    Repeater {
                        model: [15, 30, 60]

                        Rectangle {
                            required property int modelData
                            required property int index
                            property bool selected: backend.checkInInterval === modelData

                            width: 80
                            height: 40
                            radius: 4
                            color: selected ? "#1f2937"
                                 : intervalMa.containsMouse ? "#f0f0f0" : "#ffffff"
                            border.color: "#e5e7eb"
                            border.width: selected ? 0 : 1

                            Label {
                                anchors.centerIn: parent
                                text: modelData === 60 ? "1 hour" : modelData + " min"
                                font.pixelSize: 14
                                color: selected ? "#ffffff" : "#6b7280"
                            }

                            MouseArea {
                                id: intervalMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: backend.setCheckInInterval(modelData)
                            }
                        }
                    }
                }

                // ── Data ──────────────────────────────────────────
                Label {
                    text: "Data"
                    font.pixelSize: 20
                    font.bold: true
                    color: "#1f2937"
                    Layout.bottomMargin: 8
                }

                // Export button
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 4
                    color: exportMa.containsMouse ? "#374151" : "#1f2937"
                    Layout.bottomMargin: 8

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Label {
                            text: "\u2B06"
                            font.pixelSize: 14
                            color: "#f9fafb"
                        }
                        Label {
                            text: "Export data (.json)"
                            font.pixelSize: 14
                            color: "#f9fafb"
                        }
                    }

                    MouseArea {
                        id: exportMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: exportDialog.open()
                    }
                }

                // Import button
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 4
                    color: importMa.containsMouse ? "#374151" : "#1f2937"
                    Layout.bottomMargin: 16

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Label {
                            text: "\u2B07"
                            font.pixelSize: 14
                            color: "#f9fafb"
                        }
                        Label {
                            text: "Import data (.json)"
                            font.pixelSize: 14
                            color: "#f9fafb"
                        }
                    }

                    MouseArea {
                        id: importMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: importDialog.open()
                    }
                }

                // ── Archived projects ─────────────────────────────
                Label {
                    text: "Archived Projects"
                    font.pixelSize: 20
                    font.bold: true
                    color: "#1f2937"
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                }

                // Empty archived state
                Label {
                    visible: settingsRoot.archivedProjects.length === 0
                    text: "No archived projects"
                    font.pixelSize: 13
                    color: "#9ca3af"
                    Layout.bottomMargin: 16
                }

                // Archived project rows
                Repeater {
                    model: settingsRoot.archivedProjects

                    Rectangle {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        height: archivedRow.implicitHeight + 16
                        radius: 6
                        color: "#f9fafb"
                        border.color: "#e5e7eb"
                        border.width: 1
                        Layout.bottomMargin: 6

                        RowLayout {
                            id: archivedRow
                            anchors { left: parent.left; right: parent.right
                                      verticalCenter: parent.verticalCenter
                                      margins: 12 }
                            spacing: 8

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Label {
                                    text: modelData.name
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: "#374151"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Label {
                                    visible: modelData.billingCode !== ""
                                    text: modelData.billingCode
                                    font.pixelSize: 11
                                    color: "#9ca3af"
                                }
                            }

                            Rectangle {
                                implicitWidth: reinstateLbl.implicitWidth + 20
                                height: 32; radius: 4
                                color: reinstateMa.containsMouse ? "#374151" : "#1f2937"

                                Label {
                                    id: reinstateLbl
                                    anchors.centerIn: parent
                                    text: "Reinstate"
                                    font.pixelSize: 12
                                    color: "white"
                                }
                                MouseArea {
                                    id: reinstateMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: backend.reinstateProject(modelData.name)
                                }
                            }
                        }
                    }
                }

                Item { height: 8 }

                // Clear history
                Rectangle {
                    width: clearLabel.implicitWidth + 28
                    height: 40
                    radius: 4
                    color: clearMa.containsMouse ? "#fee2e2" : "#fff0f0"
                    border.color: "#fecaca"
                    border.width: 1

                    Label {
                        id: clearLabel
                        anchors.centerIn: parent
                        text: "Clear all history"
                        font.pixelSize: 14
                        color: "#ef4444"
                    }

                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clearConfirmDialog.open()
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    Dialog {
        id: clearConfirmDialog
        title: "Clear History"
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Yes | Dialog.No

        Label {
            text: "Clear all history? This cannot be undone."
            font.pixelSize: 14
        }

        onAccepted: backend.clearHistory()
    }
}
