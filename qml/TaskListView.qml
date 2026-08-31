import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: taskListRoot

    property bool showCompleted: false
    property var completedTasks: []

    function refreshCompleted() {
        completedTasks = backend.getCompletedTasks()
    }

    Component.onCompleted: refreshCompleted()

    Connections {
        target: backend
        function onCompletedTasksChanged() { taskListRoot.refreshCompleted() }
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
                    text: "Tasks"
                    font.pixelSize: 24
                    font.bold: true
                    color: "#1f2937"
                    Layout.bottomMargin: 10
                }

                // Empty state
                Label {
                    text: "Add a task to get started"
                    font.pixelSize: 14
                    color: "#adb5bd"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 30
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
                        required property int    index

                        Layout.fillWidth: true
                        height: 70
                        radius: 6
                        color: isActive ? "#eef4ff" : "#ffffff"
                        border.color: isActive ? "#93c5fd" : "#e5e7eb"
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
                                color: deleteMa.containsMouse ? "#ef4444" : "#d1d5db"

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

                            // Done check — just left of delete
                            Rectangle {
                                id: doneBtn
                                anchors.right: deleteBtn.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 26; height: 26; radius: 13
                                color: doneMa.containsMouse ? "#dcfce7" : "#ffffff"
                                border.color: doneMa.containsMouse ? "#16a34a" : "#e5e7eb"
                                border.width: 1

                                Label {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    font.pixelSize: 13
                                    color: doneMa.containsMouse ? "#16a34a" : "#9ca3af"
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
                                color: isActive ? "#dbeafe" : "transparent"
                                border.color: isActive ? "#93c5fd" : "transparent"
                                border.width: isActive ? 1 : 0

                                gradient: isActive ? null : startGradient

                                Gradient {
                                    id: startGradient
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: startMa.containsMouse ? "#15803d" : "#16a34a" }
                                    GradientStop { position: 1.0; color: startMa.containsMouse ? "#166534" : "#15803d" }
                                }

                                Label {
                                    id: activeLbl
                                    anchors.centerIn: parent
                                    visible: isActive
                                    text: "● Active"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#2563eb"
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
                                    color: isActive ? "#2563eb" : "#1f2937"
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Row {
                                    spacing: 6

                                    Rectangle {
                                        height: 16; radius: 3
                                        width: projLabel.implicitWidth + 8
                                        color: "#f0f4ff"

                                        Label {
                                            id: projLabel
                                            anchors.centerIn: parent
                                            text: project
                                            font.pixelSize: 10
                                            color: "#4a86c8"
                                        }
                                    }

                                    Label {
                                        text: "· " + timeText
                                        font.pixelSize: 11
                                        color: "#9ca3af"
                                        anchors.verticalCenter: parent.verticalCenter
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
                    radius: 6
                    color: completedNavMa.containsMouse ? "#f9fafb" : "#ffffff"
                    border.color: "#e5e7eb"; border.width: 1
                    Layout.topMargin: 8

                    RowLayout {
                        anchors { fill: parent; margins: 12 }
                        spacing: 8
                        Label {
                            text: "Completed"
                            font.pixelSize: 14; color: "#374151"
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            visible: taskListRoot.completedTasks.length > 0
                            implicitWidth: completedCountLbl.implicitWidth + 12
                            height: 20; radius: 10
                            color: "#e5e7eb"
                            Label { id: completedCountLbl; anchors.centerIn: parent
                                    text: taskListRoot.completedTasks.length
                                    font.pixelSize: 11; color: "#6b7280" }
                        }
                        Label { text: "›"; font.pixelSize: 18; color: "#9ca3af" }
                    }
                    MouseArea {
                        id: completedNavMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: taskListRoot.showCompleted = true
                    }
                }

                // New Task button
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 4
                    color: newTaskMa.containsMouse ? "#374151" : "#1f2937"
                    Layout.topMargin: 6

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Label {
                            text: "+"
                            font.pixelSize: 18
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Label {
                            text: "New Task"
                            font.pixelSize: 14
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: newTaskMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: taskDialog.open()
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
            color: compBackMa.containsMouse ? "#1f2937" : "#6b7280"
            Layout.bottomMargin: 4
            MouseArea {
                id: compBackMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: taskListRoot.showCompleted = false
            }
        }

        Label {
            text: "Completed Tasks"
            font.pixelSize: 20; font.bold: true; color: "#1f2937"
            Layout.bottomMargin: 4
        }
        Label {
            text: "Reopen a task to make it active again in your list."
            font.pixelSize: 13; color: "#6b7280"
            Layout.bottomMargin: 16
        }

        Label {
            visible: taskListRoot.completedTasks.length === 0
            text: "No completed tasks yet"
            font.pixelSize: 14; color: "#9ca3af"
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
                        radius: 6
                        color: "#ffffff"
                        border.color: "#e5e7eb"; border.width: 1

                        RowLayout {
                            id: compRow
                            anchors { left: parent.left; right: parent.right
                                      verticalCenter: parent.verticalCenter; margins: 14 }
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                Label {
                                    text: modelData.title
                                    font.pixelSize: 14; font.bold: true; color: "#374151"
                                    elide: Text.ElideRight; Layout.fillWidth: true
                                }
                                Label {
                                    text: modelData.project + " · " + modelData.time
                                    font.pixelSize: 11; color: "#9ca3af"
                                }
                            }

                            Rectangle {
                                implicitWidth: reopenLbl.implicitWidth + 20
                                height: 34; radius: 4
                                color: reopenMa.containsMouse ? "#374151" : "#1f2937"
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
