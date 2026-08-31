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

    // Empty taskId = create mode. To edit, set taskId/initialTitle/
    // initialProject/initialDueDate before calling open().
    property string taskId: ""
    property string initialTitle: ""
    property string initialProject: ""
    property string initialDueDate: ""   // "" or "YYYY-MM-DD"
    property bool hasDueDate: false

    // Reset/populate fields each time the dialog opens
    onAboutToShow: {
        projectCombo.model = backend.getProjectNames()
        if (taskDialog.taskId === "") {
            titleField.text = ""
            projectCombo.currentIndex = projectCombo.model.length > 0 ? 0 : -1
            taskDialog.hasDueDate = false
            dueDatePicker.year = new Date().getFullYear()
            dueDatePicker.month = new Date().getMonth() + 1
            dueDatePicker.day = new Date().getDate()
        } else {
            titleField.text = taskDialog.initialTitle
            var idx = projectCombo.model.indexOf(taskDialog.initialProject)
            projectCombo.currentIndex = idx >= 0 ? idx : (projectCombo.model.length > 0 ? 0 : -1)
            taskDialog.hasDueDate = taskDialog.initialDueDate !== ""
            if (taskDialog.hasDueDate) dueDatePicker.setFromString(taskDialog.initialDueDate)
        }
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
            text: taskDialog.taskId === "" ? "New Task" : "Edit Task"
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
                    if (taskDialog.canCreate) submit()
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

        // ── Due Date ─────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: taskDialog.hasDueDate ? 12 : 18
            spacing: 0

            Label {
                text: "Due Date"
                font.pixelSize: 12
                color: "#6b7280"
                Layout.fillWidth: true
            }

            Rectangle {
                width: 40; height: 22; radius: 11
                color: taskDialog.hasDueDate ? "#2563eb" : "#d1d5db"
                Behavior on color { ColorAnimation { duration: 120 } }

                Rectangle {
                    width: 16; height: 16; radius: 8
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                    x: taskDialog.hasDueDate ? parent.width - width - 3 : 3
                    Behavior on x { NumberAnimation { duration: 120 } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: taskDialog.hasDueDate = !taskDialog.hasDueDate
                }
            }
        }

        DatePicker {
            id: dueDatePicker
            Layout.fillWidth: true
            Layout.bottomMargin: 18
            visible: taskDialog.hasDueDate
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
                    text: taskDialog.taskId === "" ? "Create Task" : "Save Changes"
                    font.pixelSize: 14
                    color: "white"
                }
                MouseArea {
                    id: createMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: taskDialog.canCreate ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (taskDialog.canCreate) submit()
                }
            }
        }
    }

    property bool canCreate: titleField.text.trim() !== "" && projectCombo.currentIndex >= 0

    function submit() {
        var due = taskDialog.hasDueDate ? dueDatePicker.dateStr() : ""
        if (taskDialog.taskId === "") {
            backend.addTask(titleField.text.trim(), projectCombo.currentText, due)
        } else {
            backend.editTask(taskDialog.taskId, titleField.text.trim(), projectCombo.currentText, due)
        }
        taskDialog.close()
    }
}
