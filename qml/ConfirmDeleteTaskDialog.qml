import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: confirmDeleteTaskDialog
    title: ""
    modal: true
    width: 320
    anchors.centerIn: parent
    closePolicy: Popup.NoAutoClose

    property string taskId: ""
    property string taskTitle: ""

    background: Rectangle {
        radius: 8
        color: "#ffffff"
        border.color: "#e5e7eb"
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 0

        Label {
            text: "Delete task?"
            font.pixelSize: 18
            font.bold: true
            color: "#1f2937"
            Layout.bottomMargin: 10
        }

        Label {
            text: "“" + confirmDeleteTaskDialog.taskTitle + "”"
            font.pixelSize: 14
            font.bold: true
            color: "#374151"
            Layout.bottomMargin: 6
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Label {
            text: "The task will be removed from your list. Any time already logged against its project is kept."
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
                    onClicked: confirmDeleteTaskDialog.close()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 40; radius: 4
                color: deleteMa.containsMouse ? "#b91c1c" : "#dc2626"

                Label {
                    anchors.centerIn: parent
                    text: "Delete"
                    font.pixelSize: 14
                    color: "white"
                }
                MouseArea {
                    id: deleteMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        backend.deleteTask(confirmDeleteTaskDialog.taskId)
                        confirmDeleteTaskDialog.close()
                    }
                }
            }
        }
    }
}
