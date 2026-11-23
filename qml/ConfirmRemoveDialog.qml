import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: confirmRemoveDialog
    title: ""
    modal: true
    width: 320
    anchors.centerIn: parent
    closePolicy: Popup.NoAutoClose

    property string projectName: ""

    background: Rectangle {
        radius: 8
        color: "#ffffff"
        border.color: "#e2e8f0"
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 0

        Label {
            text: "Archive project?"
            font.pixelSize: 18
            font.bold: true
            color: "#0f172a"
            Layout.bottomMargin: 10
        }

        Label {
            text: "\u201c" + confirmRemoveDialog.projectName + "\u201d"
            font.pixelSize: 14
            font.bold: true
            color: "#1e293b"
            Layout.bottomMargin: 6
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Label {
            text: "The project will be hidden from the timer. Its history is preserved and it can be reinstated from Settings."
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
                    onClicked: confirmRemoveDialog.close()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 40; radius: 8
                color: archiveMa.containsMouse ? "#4338ca" : "#4f46e5"

                Label {
                    anchors.centerIn: parent
                    text: "Archive"
                    font.pixelSize: 14
                    color: "white"
                }
                MouseArea {
                    id: archiveMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        backend.archiveProject(confirmRemoveDialog.projectName)
                        confirmRemoveDialog.close()
                    }
                }
            }
        }
    }
}
