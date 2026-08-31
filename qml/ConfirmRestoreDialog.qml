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
        border.color: "#e5e7eb"
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 0

        Label {
            text: "Restore this backup?"
            font.pixelSize: 18
            font.bold: true
            color: "#1f2937"
            Layout.bottomMargin: 10
        }

        Label {
            text: "“" + confirmRestoreDialog.backupLabel + "”"
            font.pixelSize: 14
            font.bold: true
            color: "#374151"
            Layout.bottomMargin: 6
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Label {
            text: "This replaces all current projects, tasks, and history with the backup's contents. Your current data is snapshotted first so this can be undone."
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
                color: cancelMa.containsMouse ? "#f3f4f6" : "#ffffff"
                border.color: "#e5e7eb"; border.width: 1

                Label {
                    anchors.centerIn: parent
                    text: "Cancel"
                    font.pixelSize: 14
                    color: "#6b7280"
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
                height: 40; radius: 4
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
