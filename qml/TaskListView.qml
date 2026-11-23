import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: taskListRoot

    property bool showCompleted: false
    property var completedTasks: []
    property var carryOverTasks: []

    function refreshCompleted() {
        completedTasks = backend.getCompletedTasks()
    }

    function refreshCarryOver() {
        carryOverTasks = backend.getCarryOverTasks()
    }

    function quickAdd() {
        if (quickTitleField.text.trim() === "" || quickProjectCombo.currentIndex < 0) return
        backend.addTask(quickTitleField.text.trim(), quickProjectCombo.currentText, "", quickEstimateStepper.estimateMinutes)
        quickTitleField.text = ""
        quickEstimateStepper.estimateMinutes = 30
    }

    Component.onCompleted: {
        refreshCompleted()
        refreshCarryOver()
    }

    Connections {
        target: backend
        function onCompletedTasksChanged() { taskListRoot.refreshCompleted() }
        function onTasksChanged() {
            taskListRoot.refreshCompleted()
            taskListRoot.refreshCarryOver()
        }
    }

    TaskDialog { id: taskDialog }
    ConfirmDeleteTaskDialog { id: confirmDeleteTaskDialog }

    // ── Pending tasks page ──────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        visible: !taskListRoot.showCompleted

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: pendingCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: pendingCol
                width: parent.width
                spacing: 6

                Label {
                    text: "Today's Plan"
                    font.pixelSize: 24
                    font.bold: true
                    color: "#0f172a"
                    Layout.bottomMargin: 2
                }

                Label {
                    text: "Planned " + backend.todayEstimateTotal + " · Logged " + backend.todayTotal
                    font.pixelSize: 13
                    color: "#64748b"
                    Layout.bottomMargin: 14
                }

                // ── Quick add ─────────────────────────────────────────────
                Label {
                    text: "What do you want to work on today?"
                    font.pixelSize: 13
                    font.bold: true
                    color: "#1e293b"
                    Layout.bottomMargin: 6
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 16
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        height: 38
                        radius: 8
                        color: "#ffffff"
                        border.color: quickTitleField.activeFocus ? "#4f46e5" : "#e2e8f0"
                        border.width: 1

                        TextInput {
                            id: quickTitleField
                            anchors.fill: parent
                            anchors.margins: 10
                            verticalAlignment: TextInput.AlignVCenter
                            font.pixelSize: 13
                            color: "#0f172a"
                            clip: true

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Add a task…"
                                color: "#94a3b8"
                                font.pixelSize: 13
                                visible: !quickTitleField.text && !quickTitleField.activeFocus
                            }

                            Keys.onReturnPressed: quickAdd()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ComboBox {
                            id: quickProjectCombo
                            Layout.fillWidth: true
                            model: backend.getProjectNames()
                            font.pixelSize: 13

                            background: Rectangle {
                                implicitHeight: 34
                                radius: 8
                                color: "#ffffff"
                                border.color: quickProjectCombo.activeFocus ? "#4f46e5" : "#e2e8f0"
                                border.width: 1
                            }
                            contentItem: Label {
                                text: quickProjectCombo.displayText
                                font.pixelSize: 13
                                color: "#0f172a"
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 10
                                rightPadding: 20
                                elide: Text.ElideRight
                            }
                            indicator: Label {
                                text: "⌄"
                                font.pixelSize: 14
                                color: "#94a3b8"
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        EstimateStepper {
                            id: quickEstimateStepper
                        }

                        Rectangle {
                            width: 34; height: 34; radius: 8
                            color: quickAddMa.containsMouse ? "#4338ca" : "#4f46e5"
                            opacity: quickTitleField.text.trim() !== "" && quickProjectCombo.currentIndex >= 0 ? 1.0 : 0.5

                            Label {
                                anchors.centerIn: parent
                                text: "+"
                                font.pixelSize: 18
                                color: "white"
                            }
                            MouseArea {
                                id: quickAddMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: quickAdd()
                            }
                        }
                    }
                }

                // Empty state
                Label {
                    text: "Add a task to get started"
                    font.pixelSize: 14
                    color: "#94a3b8"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 10
                    visible: taskRepeater.count === 0
                }

                // Pending task list
                Repeater {
                    id: taskRepeater
                    model: backend.taskModel

                    Rectangle {
                        required property string taskId
                        required property string title
                        required property string project
                        required property bool   isActive
                        required property string timeText
                        required property string dueDate
                        required property string dueDateLabel
                        required property string estimateLabel
                        required property int    estimateMinutes
                        required property int    index

                        Layout.fillWidth: true
                        height: 70
                        radius: 10
                        color: isActive ? "#eef2ff" : "#ffffff"
                        border.color: isActive ? "#c7d2fe" : "#e2e8f0"
                        border.width: 1

                        Item {
                            id: taskRow
                            anchors.fill: parent
                            anchors.margins: 14

                            // Delete — anchored to far right
                            Label {
                                id: deleteBtn
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "✕"
                                font.pixelSize: 15
                                color: deleteMa.containsMouse ? "#ef4444" : "#cbd5e1"

                                MouseArea {
                                    id: deleteMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        confirmDeleteTaskDialog.taskId = taskId
                                        confirmDeleteTaskDialog.taskTitle = title
                                        confirmDeleteTaskDialog.open()
                                    }
                                }
                            }

                            // Edit — just left of delete
                            Label {
                                id: editBtn
                                anchors.right: deleteBtn.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: "✎"
                                font.pixelSize: 14
                                color: editMa.containsMouse ? "#4f46e5" : "#cbd5e1"

                                MouseArea {
                                    id: editMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        taskDialog.taskId = taskId
                                        taskDialog.initialTitle = title
                                        taskDialog.initialProject = project
                                        taskDialog.initialDueDate = dueDate
                                        taskDialog.initialEstimateMinutes = estimateMinutes
                                        taskDialog.open()
                                    }
                                }
                            }

                            // Done check — just left of edit
                            Rectangle {
                                id: doneBtn
                                anchors.right: editBtn.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 26; height: 26; radius: 13
                                color: doneMa.containsMouse ? "#d1fae5" : "#ffffff"
                                border.color: doneMa.containsMouse ? "#059669" : "#e2e8f0"
                                border.width: 1

                                Label {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    font.pixelSize: 13
                                    color: doneMa.containsMouse ? "#059669" : "#94a3b8"
                                }

                                MouseArea {
                                    id: doneMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: backend.completeTask(taskId)
                                }
                            }

                            // Active badge or Start button — anchored just left of done check
                            Rectangle {
                                id: actionBtn
                                anchors.right: doneBtn.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: isActive ? (activeLbl.implicitWidth + 20) : (startRow.implicitWidth + 24)
                                height: 34
                                radius: 17
                                color: isActive ? "#e0e7ff" : "transparent"
                                border.color: isActive ? "#c7d2fe" : "transparent"
                                border.width: isActive ? 1 : 0

                                gradient: isActive ? null : startGradient

                                Gradient {
                                    id: startGradient
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: startMa.containsMouse ? "#4338ca" : "#4f46e5" }
                                    GradientStop { position: 1.0; color: startMa.containsMouse ? "#4338ca" : "#4f46e5" }
                                }

                                Label {
                                    id: activeLbl
                                    anchors.centerIn: parent
                                    visible: isActive
                                    text: "● Active"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#4f46e5"
                                }

                                Row {
                                    id: startRow
                                    anchors.centerIn: parent
                                    visible: !isActive
                                    spacing: 5

                                    Label {
                                        text: "▶"
                                        font.pixelSize: 10
                                        color: "white"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Label {
                                        text: "Start"
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: "white"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: startMa
                                    anchors.fill: parent
                                    enabled: !isActive
                                    hoverEnabled: true
                                    cursorShape: isActive ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: if (!isActive) backend.startTask(taskId)
                                }
                            }

                            // Task info — anchored left, right edge stops at action button
                            ColumnLayout {
                                anchors.left: parent.left
                                anchors.right: actionBtn.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                Label {
                                    text: title
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: isActive ? "#4f46e5" : "#0f172a"
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Row {
                                    spacing: 6

                                    Rectangle {
                                        height: 16; radius: 5
                                        width: projLabel.implicitWidth + 8
                                        color: "#eef2ff"

                                        Label {
                                            id: projLabel
                                            anchors.centerIn: parent
                                            text: project
                                            font.pixelSize: 10
                                            color: "#4f46e5"
                                        }
                                    }

                                    Label {
                                        text: "· " + timeText + (estimateLabel ? " / " + estimateLabel + " est" : "")
                                        font.pixelSize: 11
                                        color: "#94a3b8"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Label {
                                        visible: dueDateLabel !== ""
                                        text: "· Due " + dueDateLabel
                                        font.pixelSize: 11
                                        color: "#f59e0b"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Carried over from yesterday ──────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    spacing: 6
                    visible: taskListRoot.carryOverTasks.length > 0

                    Label {
                        text: "Carried over from yesterday"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#92400e"
                    }

                    Repeater {
                        model: taskListRoot.carryOverTasks

                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            height: carryRow.implicitHeight + 16
                            radius: 10
                            color: "#fffbeb"
                            border.color: "#fde68a"
                            border.width: 1

                            RowLayout {
                                id: carryRow
                                anchors { left: parent.left; right: parent.right
                                          verticalCenter: parent.verticalCenter; margins: 12 }
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2
                                    Label {
                                        text: modelData.title
                                        font.pixelSize: 14; font.bold: true; color: "#78350f"
                                        elide: Text.ElideRight; Layout.fillWidth: true
                                    }
                                    Label {
                                        text: modelData.project + (modelData.estimateLabel ? " · " + modelData.estimateLabel : "")
                                        font.pixelSize: 11; color: "#b45309"
                                    }
                                }

                                Rectangle {
                                    implicitWidth: pullLbl.implicitWidth + 18
                                    height: 30; radius: 8
                                    color: pullMa.containsMouse ? "#92400e" : "#b45309"
                                    Label {
                                        id: pullLbl; anchors.centerIn: parent
                                        text: "+ Add to Today"; font.pixelSize: 12; color: "white"
                                    }
                                    MouseArea {
                                        id: pullMa; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.pullToToday(modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }

                // Completed tasks nav row
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: 10
                    color: completedNavMa.containsMouse ? "#f8fafc" : "#ffffff"
                    border.color: "#e2e8f0"; border.width: 1
                    Layout.topMargin: 8

                    RowLayout {
                        anchors { fill: parent; margins: 12 }
                        spacing: 8
                        Label {
                            text: "Completed"
                            font.pixelSize: 14; color: "#1e293b"
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            visible: taskListRoot.completedTasks.length > 0
                            implicitWidth: completedCountLbl.implicitWidth + 12
                            height: 20; radius: 10
                            color: "#e2e8f0"
                            Label { id: completedCountLbl; anchors.centerIn: parent
                                    text: taskListRoot.completedTasks.length
                                    font.pixelSize: 11; color: "#64748b" }
                        }
                        Label { text: "›"; font.pixelSize: 18; color: "#94a3b8" }
                    }
                    MouseArea {
                        id: completedNavMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: taskListRoot.showCompleted = true
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    // ── Completed tasks sub-page ────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        visible: taskListRoot.showCompleted

        Label {
            text: "← Back"
            font.pixelSize: 14
            color: compBackMa.containsMouse ? "#0f172a" : "#64748b"
            Layout.bottomMargin: 4
            MouseArea {
                id: compBackMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: taskListRoot.showCompleted = false
            }
        }

        Label {
            text: "Completed Tasks"
            font.pixelSize: 20; font.bold: true; color: "#0f172a"
            Layout.bottomMargin: 4
        }
        Label {
            text: "Reopen a task to make it active again in your list."
            font.pixelSize: 13; color: "#64748b"
            Layout.bottomMargin: 16
        }

        Label {
            visible: taskListRoot.completedTasks.length === 0
            text: "No completed tasks yet"
            font.pixelSize: 14; color: "#94a3b8"
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 20
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: taskListRoot.completedTasks.length > 0
            contentHeight: compCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: compCol
                width: parent.width
                spacing: 8

                Repeater {
                    model: taskListRoot.completedTasks

                    Rectangle {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        height: compRow.implicitHeight + 20
                        radius: 10
                        color: "#ffffff"
                        border.color: "#e2e8f0"; border.width: 1

                        RowLayout {
                            id: compRow
                            anchors { left: parent.left; right: parent.right
                                      verticalCenter: parent.verticalCenter; margins: 14 }
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                Label {
                                    text: modelData.title
                                    font.pixelSize: 14; font.bold: true; color: "#1e293b"
                                    elide: Text.ElideRight; Layout.fillWidth: true
                                }
                                Label {
                                    text: modelData.project + " · " + modelData.time
                                    font.pixelSize: 11; color: "#94a3b8"
                                }
                            }

                            Rectangle {
                                implicitWidth: reopenLbl.implicitWidth + 20
                                height: 34; radius: 8
                                color: reopenMa.containsMouse ? "#4338ca" : "#4f46e5"
                                Label {
                                    id: reopenLbl; anchors.centerIn: parent
                                    text: "Reopen"; font.pixelSize: 13; color: "white"
                                }
                                MouseArea {
                                    id: reopenMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: backend.reopenTask(modelData.id)
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
