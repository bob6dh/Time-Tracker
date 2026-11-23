import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

// "What are you working on?" — a small card that slides up next to the tray
// when keyboard/mouse activity is detected while no timer is running.
// One click on a task or project starts tracking it.
//
// It never takes keyboard focus (Qt.WindowDoesNotAcceptFocus), so popping up
// while you're typing elsewhere won't steal your keystrokes.
Window {
    id: prompt
    objectName: "activityPrompt"
    title: "What are you working on?"
    width: 360
    height: card.implicitHeight + 2 * shadowPad
    color: "transparent"
    // Declared inside Main's window, Qt would make this a transient child that
    // can't be shown while the main window is hidden in the tray. null makes it
    // an independent top-level window.
    transientParent: null
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus

    readonly property int shadowPad: 10
    readonly property int maxProjects: 12
    property var tasks: []
    property var projects: []

    signal openAppRequested()

    function showPrompt() {
        var opts = backend.getActivityPromptOptions()
        tasks = opts.tasks.slice(0, 4)
        projects = opts.projects.slice(0, maxProjects)
        if (projects.length === 0 && tasks.length === 0) {
            backend.snoozeActivityPrompt(1)  // nothing to pick; don't leave the backend thinking we're on screen
            return
        }
        var g = backend.primaryAvailableGeometry()
        x = g.x + g.width - width - 8
        y = g.y + g.height - height - 8
        card.opacity = 0
        card.slide = 16
        visible = true
        raise()
        enterAnim.restart()
    }

    function choose(fn) {
        visible = false
        fn()
    }

    function dismiss(minutes) {
        visible = false
        if (minutes === undefined) backend.dismissActivityPrompt()
        else backend.snoozeActivityPrompt(minutes)
    }

    // Started from somewhere else (main window, tray) — get out of the way.
    Connections {
        target: backend
        function onActiveProjectChanged() {
            if (backend.activeProject !== "") prompt.visible = false
        }
    }

    ParallelAnimation {
        id: enterAnim
        NumberAnimation { target: card; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "slide"; to: 0; duration: 220; easing.type: Easing.OutCubic }
    }

    // Soft shadow
    Rectangle {
        x: card.x - 2; y: card.y + 3 + card.slide
        width: card.width + 4; height: card.height + 2
        radius: card.radius + 2
        color: "#1a0f172a"
        opacity: card.opacity
    }

    Rectangle {
        id: card
        property real slide: 0
        x: prompt.shadowPad
        y: prompt.shadowPad + slide
        width: prompt.width - 2 * prompt.shadowPad
        implicitHeight: content.implicitHeight + 36
        radius: 16
        color: "#ffffff"
        border.color: "#e2e8f0"

        ColumnLayout {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
            spacing: 0

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    width: 32; height: 32; radius: 10
                    color: "#eef2ff"
                    Label { anchors.centerIn: parent; text: "⏱"; font.pixelSize: 16; color: "#4f46e5" }
                }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    Label {
                        text: "What are you working on?"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: "#0f172a"
                    }
                    Label {
                        text: "Click one to start the timer"
                        font.pixelSize: 12
                        color: "#94a3b8"
                    }
                }
                Rectangle {
                    width: 28; height: 28; radius: 8
                    Layout.alignment: Qt.AlignTop
                    color: closeMa.containsMouse ? "#f1f5f9" : "transparent"
                    Label { anchors.centerIn: parent; text: "✕"; font.pixelSize: 12; color: "#94a3b8" }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: prompt.dismiss()
                    }
                }
            }

            // Today's tasks
            Label {
                visible: prompt.tasks.length > 0
                text: "TODAY'S TASKS"
                font.pixelSize: 10
                font.letterSpacing: 0.8
                font.weight: Font.DemiBold
                color: "#94a3b8"
                Layout.topMargin: 16
                Layout.bottomMargin: 6
            }
            Repeater {
                model: prompt.tasks
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    height: 44
                    radius: 10
                    color: taskMa.containsMouse ? "#eef2ff" : "#f8fafc"
                    border.color: taskMa.containsMouse ? "#c7d2fe" : "#eef0f4"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            Label {
                                text: modelData.title
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: "#0f172a"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Label {
                                text: modelData.project
                                font.pixelSize: 11
                                color: "#64748b"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                        Label {
                            text: "▶"
                            font.pixelSize: 11
                            color: "#4f46e5"
                            opacity: taskMa.containsMouse ? 1 : 0
                        }
                    }
                    MouseArea {
                        id: taskMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var id = modelData.id
                            prompt.choose(function() { backend.startTask(id) })
                        }
                    }
                }
            }

            // Projects
            Label {
                visible: prompt.projects.length > 0
                text: "PROJECTS"
                font.pixelSize: 10
                font.letterSpacing: 0.8
                font.weight: Font.DemiBold
                color: "#94a3b8"
                Layout.topMargin: prompt.tasks.length > 0 ? 10 : 16
                Layout.bottomMargin: 6
            }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: prompt.projects
                    Rectangle {
                        required property var modelData
                        height: 34
                        width: Math.min(chipRow.implicitWidth + 24, content.width)
                        radius: 17
                        color: chipMa.containsMouse ? "#4f46e5" : "#ffffff"
                        border.color: chipMa.containsMouse ? "#4f46e5" : "#e2e8f0"
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 6
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                anchors.verticalCenter: parent.verticalCenter
                                color: chipMa.containsMouse ? "#ffffff"
                                     : modelData.billable ? "#10b981" : "#cbd5e1"
                            }
                            Label {
                                text: modelData.name
                                font.pixelSize: 13
                                color: chipMa.containsMouse ? "#ffffff" : "#0f172a"
                                elide: Text.ElideRight
                                width: Math.min(implicitWidth, content.width - 48)
                            }
                        }
                        MouseArea {
                            id: chipMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var name = modelData.name
                                prompt.choose(function() { backend.startProject(name) })
                            }
                        }
                    }
                }
            }

            // Footer
            Rectangle { Layout.fillWidth: true; Layout.topMargin: 14; height: 1; color: "#f1f5f9" }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 10
                spacing: 4
                Repeater {
                    model: [
                        { label: "Not working", minutes: -1 },
                        { label: "Snooze 1 hour", minutes: 60 }
                    ]
                    Rectangle {
                        required property var modelData
                        height: 28; radius: 8
                        width: footLbl.implicitWidth + 20
                        color: footMa.containsMouse ? "#f1f5f9" : "transparent"
                        Label {
                            id: footLbl
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: 12
                            color: "#64748b"
                        }
                        MouseArea {
                            id: footMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.minutes < 0 ? prompt.dismiss() : prompt.dismiss(modelData.minutes)
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                Label {
                    text: "Open app"
                    font.pixelSize: 12
                    color: openMa.containsMouse ? "#4338ca" : "#4f46e5"
                    MouseArea {
                        id: openMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { prompt.dismiss(1); prompt.openAppRequested() }
                    }
                }
            }
        }
    }
}
