import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

// Periodic "Still working on X?" card, shown above the tray. Always on top,
// no taskbar button, never steals keyboard focus.
Window {
    id: checkInWindow
    objectName: "checkInWindow"
    title: "Time Tracker — Check In"
    width: 360
    height: card.implicitHeight + 20
    color: "transparent"
    // Declared inside Main's window, Qt would make this a transient child that
    // can't be shown while the main window is hidden in the tray. null makes it
    // an independent top-level window.
    transientParent: null
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus

    property int secondsLeft: 0
    property string projectName: ""
    property string taskTitle: ""

    function showWindow() {
        projectName = backend.activeProject
        taskTitle = backend.activeTaskTitle
        secondsLeft = backend.inactivityTimeoutSecs
        var g = backend.primaryAvailableGeometry()
        x = g.x + g.width - width - 8
        y = g.y + g.height - height - 8
        visible = true
        raise()
        countdownTimer.start()
    }

    function hideWindow() {
        countdownTimer.stop()
        visible = false
    }

    function formatCountdown(secs) {
        var m = Math.floor(secs / 60)
        var s = secs % 60
        return m + ":" + (s < 10 ? "0" + s : s)
    }

    // Close if the backend stopped the timer (timeout or "No" from elsewhere)
    Connections {
        target: backend
        function onActiveProjectChanged() {
            if (backend.activeProject === "") checkInWindow.hideWindow()
        }
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: if (checkInWindow.secondsLeft > 0) checkInWindow.secondsLeft--
    }

    Rectangle {
        x: card.x - 2; y: card.y + 3
        width: card.width + 4; height: card.height + 2
        radius: card.radius + 2
        color: "#1a0f172a"
    }

    Rectangle {
        id: card
        x: 10; y: 10
        width: parent.width - 20
        implicitHeight: col.implicitHeight + 36
        radius: 16
        color: "#ffffff"
        border.color: "#e2e8f0"

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    width: 32; height: 32; radius: 10
                    color: "#ecfdf5"
                    Rectangle { anchors.centerIn: parent; width: 10; height: 10; radius: 5; color: "#10b981" }
                }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    Label { text: "Still working on"; font.pixelSize: 12; color: "#94a3b8" }
                    Label {
                        text: checkInWindow.projectName + "?"
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        color: "#0f172a"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Label {
                        visible: checkInWindow.taskTitle !== ""
                        text: checkInWindow.taskTitle
                        font.pixelSize: 12
                        color: "#64748b"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 16
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    height: 40; radius: 10
                    color: yesMa.containsMouse ? "#4338ca" : "#4f46e5"
                    Label {
                        anchors.centerIn: parent
                        text: "Yes, keep going"
                        font.pixelSize: 13; font.weight: Font.DemiBold
                        color: "#ffffff"
                    }
                    MouseArea {
                        id: yesMa
                        anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { backend.checkInYes(); checkInWindow.hideWindow() }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 40; radius: 10
                    color: noMa.containsMouse ? "#fef2f2" : "#ffffff"
                    border.color: noMa.containsMouse ? "#fecaca" : "#e2e8f0"
                    Label {
                        anchors.centerIn: parent
                        text: "No, stop"
                        font.pixelSize: 13
                        color: "#dc2626"
                    }
                    MouseArea {
                        id: noMa
                        anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { backend.checkInNo(); checkInWindow.hideWindow() }
                    }
                }
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 10
                text: "Auto-stopping in " + checkInWindow.formatCountdown(checkInWindow.secondsLeft)
                font.pixelSize: 11
                color: checkInWindow.secondsLeft <= 60 ? "#ef4444" : "#94a3b8"
            }
        }
    }
}
