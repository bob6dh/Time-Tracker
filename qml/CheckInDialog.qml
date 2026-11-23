import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: checkInDialog
    title: "Check In"
    anchors.centerIn: parent
    modal: true
    width: 340
    closePolicy: Popup.NoAutoClose

    property int secondsLeft: 30 * 60
    property string projectName: ""

    function formatCountdown(secs) {
        var m = Math.floor(secs / 60)
        var s = secs % 60
        return m + ":" + (s < 10 ? "0" + s : s)
    }

    onOpened: {
        projectName = backend.activeProject
        secondsLeft = backend.inactivityTimeoutSecs
        countdownTimer.start()
    }

    onClosed: {
        countdownTimer.stop()
    }

    // Auto-close if the backend stops the timer (inactivity or user clicked No)
    Connections {
        target: backend
        function onActiveProjectChanged() {
            if (backend.activeProject === "" && checkInDialog.visible) {
                checkInDialog.close()
            }
        }
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (checkInDialog.secondsLeft > 0) {
                checkInDialog.secondsLeft--
            }
        }
    }

    ColumnLayout {
        width: parent.width
        spacing: 4

        Label {
            text: "Still working on"
            font.pixelSize: 16
            font.bold: true
            color: "#0f172a"
        }

        Label {
            text: checkInDialog.projectName + "?"
            font.pixelSize: 22
            font.bold: true
            color: "#4f46e5"
            Layout.bottomMargin: 14
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: 8
                color: yesMa.containsMouse ? "#4338ca" : "#4f46e5"

                Label {
                    anchors.centerIn: parent
                    text: "Yes, continue"
                    font.pixelSize: 14
                    color: "white"
                }
                MouseArea {
                    id: yesMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        backend.checkInYes()
                        checkInDialog.close()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: 8
                color: noMa.containsMouse ? "#f1f5f9" : "#ffffff"
                border.color: "#e2e8f0"
                border.width: 1

                Label {
                    anchors.centerIn: parent
                    text: "No, stop"
                    font.pixelSize: 14
                    color: "#64748b"
                }
                MouseArea {
                    id: noMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        backend.checkInNo()
                        checkInDialog.close()
                    }
                }
            }
        }

        Label {
            Layout.topMargin: 10
            Layout.alignment: Qt.AlignHCenter
            text: "Auto-stopping in " + checkInDialog.formatCountdown(checkInDialog.secondsLeft)
            font.pixelSize: 12
            color: checkInDialog.secondsLeft <= 60 ? "#ef4444" : "#94a3b8"
        }
    }
}
