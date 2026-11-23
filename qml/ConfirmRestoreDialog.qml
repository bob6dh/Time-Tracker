import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: confirmRestoreDialog
    title: ""
    modal: true
    width: 320
    anchors.centerIn: parent
    closePolicy: Popup.NoAutoClose

    property string backupPath: ""
    property string backupLabel: ""
    property real backupMtime: 0

    background: Rectangle {
        radius: 8
        color: "#ffffff"
        border.color: "#e2e8f0"
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 0

        Label {
            text: "Restore this backup?"
            font.pixelSize: 18
            font.bold: true
            color: "#0f172a"
            Layout.bottomMargin: 10
        }

        Label {
            text: "“" + confirmRestoreDialog.backupLabel + "”"
            font.pixelSize: 14
            font.bold: true
            color: "#1e293b"
            Layout.bottomMargin: 6
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Label {
            text: "This replaces all current projects, tasks, and history with the backup's contents. Your current data is snapshotted first so this can be undone."
            font.pixelSize: 13
            color: "#64748b"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.bottomMargin: 22
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                height: 40; radius: 8
                color: cancelMa.containsMouse ? "#f1f5f9" : "#ffffff"
                border.color: "#e2e8f0"; border.width: 1

                Label {
                    anchors.centerIn: parent
                    text: "Cancel"
                    font.pixelSize: 14
                    color: "#64748b"
                }
                MouseArea {
                    id: cancelMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: confirmRestoreDialog.close()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 40; radius: 8
                color: restoreMa.containsMouse ? "#b91c1c" : "#dc2626"

                Label {
                    anchors.centerIn: parent
                    text: "Restore"
                    font.pixelSize: 14
                    color: "white"
                }
                MouseArea {
                    id: restoreMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        backend.restoreBackup(confirmRestoreDialog.backupPath, confirmRestoreDialog.backupMtime)
                        confirmRestoreDialog.close()
                    }
                }
            }
        }
    }
}
