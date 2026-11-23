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
    property int initialEstimateMinutes: 0
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
            estimateStepper.estimateMinutes = 30
        } else {
            titleField.text = taskDialog.initialTitle
            var idx = projectCombo.model.indexOf(taskDialog.initialProject)
            projectCombo.currentIndex = idx >= 0 ? idx : (projectCombo.model.length > 0 ? 0 : -1)
            taskDialog.hasDueDate = taskDialog.initialDueDate !== ""
            if (taskDialog.hasDueDate) dueDatePicker.setFromString(taskDialog.initialDueDate)
            estimateStepper.estimateMinutes = taskDialog.initialEstimateMinutes
        }
        titleField.forceActiveFocus()
    }

    background: Rectangle {
        radius: 8
        color: "#ffffff"
        border.color: "#e2e8f0"
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 0

        // Header
        Label {
            text: taskDialog.taskId === "" ? "New Task" : "Edit Task"
            font.pixelSize: 18
            font.bold: true
            color: "#0f172a"
            Layout.bottomMargin: 18
        }

        // ── Title ────────────────────────────────────────────────
        Label {
            text: "Task Title"
            font.pixelSize: 12
            color: "#64748b"
            Layout.bottomMargin: 4
        }
        Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: 8
            color: "#ffffff"
            border.color: titleField.activeFocus ? "#4f46e5" : "#e2e8f0"
            border.width: 1
            Layout.bottomMargin: 14

            TextInput {
                id: titleField
                anchors.fill: parent
                anchors.margins: 10
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: 14
                color: "#0f172a"
                clip: true

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "e.g. Write proposal"
                    color: "#94a3b8"
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
            color: "#64748b"
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

        // ── Time Estimate ────────────────────────────────────────
        Label {
            text: "Time Estimate"
            font.pixelSize: 12
            color: "#64748b"
            Layout.bottomMargin: 4
        }
        EstimateStepper {
            id: estimateStepper
            Layout.bottomMargin: 18
        }

        // ── Due Date ─────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: taskDialog.hasDueDate ? 12 : 18
            spacing: 0

            Label {
                text: "Due Date"
                font.pixelSize: 12
                color: "#64748b"
                Layout.fillWidth: true
            }

            Rectangle {
                width: 40; height: 22; radius: 11
                color: taskDialog.hasDueDate ? "#4f46e5" : "#cbd5e1"
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
                    onClicked: taskDialog.close()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 40; radius: 8
                color: !taskDialog.canCreate ? "#94a3b8"
                     : createMa.containsMouse ? "#4338ca" : "#4f46e5"

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
            backend.addTask(titleField.text.trim(), projectCombo.currentText, due, estimateStepper.estimateMinutes)
        } else {
            backend.editTask(taskDialog.taskId, titleField.text.trim(), projectCombo.currentText, due, estimateStepper.estimateMinutes)
        }
        taskDialog.close()
    }
}
