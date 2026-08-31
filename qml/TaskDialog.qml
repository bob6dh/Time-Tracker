import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: taskDialog
    title: ""
    modal: true
    width: 340
    anchors.centerIn: parent
    closePolicy: Popup.NoAutoClose

    // Reset fields each time the dialog opens
    onAboutToShow: {
        titleField.text = ""
        projectCombo.model = backend.getProjectNames()
        projectCombo.currentIndex = projectCombo.model.length > 0 ? 0 : -1
        titleField.forceActiveFocus()
    }

    background: Rectangle {
        radius: 8
        color: "#ffffff"
        border.color: "#e5e7eb"
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 0

        // Header
        Label {
            text: "New Task"
            font.pixelSize: 18
            font.bold: true
            color: "#1f2937"
            Layout.bottomMargin: 18
        }

        // ── Title ────────────────────────────────────────────────
        Label {
            text: "Task Title"
            font.pixelSize: 12
            color: "#6b7280"
            Layout.bottomMargin: 4
        }
        Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: 4
            color: "#ffffff"
            border.color: titleField.activeFocus ? "#2563eb" : "#e5e7eb"
            border.width: 1
            Layout.bottomMargin: 14

            TextInput {
                id: titleField
                anchors.fill: parent
                anchors.margins: 10
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: 14
                color: "#1f2937"
                clip: true

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "e.g. Write proposal"
                    color: "#adb5bd"
                    font.pixelSize: 14
                    visible: !titleField.text && !titleField.activeFocus
                }

                Keys.onReturnPressed: {
                    if (taskDialog.canCreate) createTask()
                }
            }
        }

        // ── Project ──────────────────────────────────────────────
        Label {
            text: "Project"
            font.pixelSize: 12
            color: "#6b7280"
            Layout.bottomMargin: 4
        }
        ComboBox {
            id: projectCombo
            Layout.fillWidth: true
            Layout.bottomMargin: 22
            model: []
        }

        Label {
            visible: projectCombo.model.length === 0
            text: "Add a project first (Timer tab) before creating tasks."
            font.pixelSize: 12
            color: "#ef4444"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.bottomMargin: 14
        }

        // ── Buttons ───────────────────────────────────────────────
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
                    onClicked: taskDialog.close()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 40; radius: 4
                color: !taskDialog.canCreate ? "#9ca3af"
                     : createMa.containsMouse ? "#374151" : "#1f2937"

                Label {
                    anchors.centerIn: parent
                    text: "Create Task"
                    font.pixelSize: 14
                    color: "white"
                }
                MouseArea {
                    id: createMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: taskDialog.canCreate ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (taskDialog.canCreate) createTask()
                }
            }
        }
    }

    property bool canCreate: titleField.text.trim() !== "" && projectCombo.currentIndex >= 0

    function createTask() {
        backend.addTask(titleField.text.trim(), projectCombo.currentText)
        taskDialog.close()
    }
}
