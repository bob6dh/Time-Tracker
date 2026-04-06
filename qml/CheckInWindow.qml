import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: checkInWindow
    title: "Time Tracker — Check In"
    width: 360
    height: contentCol.implicitHeight + 48
    minimumWidth: 320
    minimumHeight: 200
    color: "#ffffff"

    // Always-on-top, appears outside the main app window
    flags: Qt.Dialog | Qt.WindowStaysOnTopHint | Qt.WindowTitleHint | Qt.WindowCloseButtonHint

    property int secondsLeft: 0
    property string projectName: ""

    function showWindow() {
        projectName = backend.activeProject
        secondsLeft = backend.inactivityTimeoutSecs
        // Centre on the primary screen
        x = Screen.virtualX + Math.round((Screen.width  - width)  / 2)
        y = Screen.virtualY + Math.round((Screen.height - height) / 2)
        visible = true
        raise()
        requestActivate()
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

    // Closing the window via the OS ✕ button counts as "No, stop"
    onClosing: function(close) {
        close.accepted = true
        if (backend.activeProject !== "") {
            backend.checkInNo()
        }
        countdownTimer.stop()
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (checkInWindow.secondsLeft > 0) {
                checkInWindow.secondsLeft--
            }
        }
    }

    ColumnLayout {
        id: contentCol
        anchors {
            left: parent.left; right: parent.right; top: parent.top
            margins: 24; topMargin: 28
        }
        spacing: 6

        // Project question
        Label {
            text: "Still working on"
            font.pixelSize: 14
            color: "#6b7280"
        }
        Label {
            text: checkInWindow.projectName + "?"
            font.pixelSize: 22
            font.bold: true
            color: "#1f2937"
            Layout.fillWidth: true
            elide: Text.ElideRight
            Layout.bottomMargin: 16
        }

        // Yes / No buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                height: 44; radius: 6
                color: yesMa.containsMouse ? "#374151" : "#1f2937"
                Label {
                    anchors.centerIn: parent
                    text: "Yes, continue"
                    font.pixelSize: 14; font.bold: true
                    color: "#ffffff"
                }
                MouseArea {
                    id: yesMa
                    anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        backend.checkInYes()
                        checkInWindow.hideWindow()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 44; radius: 6
                color: noMa.containsMouse ? "#fee2e2" : "#fff0f0"
                border.color: "#fecaca"; border.width: 1
                Label {
                    anchors.centerIn: parent
                    text: "No, stop"
                    font.pixelSize: 14
                    color: "#ef4444"
                }
                MouseArea {
                    id: noMa
                    anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        backend.checkInNo()
                        checkInWindow.hideWindow()
                    }
                }
            }
        }

        // Countdown
        Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            Layout.bottomMargin: 4
            text: "Auto-stopping in " + checkInWindow.formatCountdown(checkInWindow.secondsLeft)
            font.pixelSize: 12
            color: checkInWindow.secondsLeft <= 60 ? "#ef4444" : "#9ca3af"
        }
    }
}
