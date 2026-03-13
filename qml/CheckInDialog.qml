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

    function formatCountdown(secs) {
        var m = Math.floor(secs / 60)
        var s = secs % 60
        return m + ":" + (s < 10 ? "0" + s : s)
    }

    onOpened: {
        secondsLeft = 30 * 60
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
            color: "#1f2937"
        }

        Label {
            text: backend.activeProject + "?"
            font.pixelSize: 22
            font.bold: true
            color: "#2563eb"
            Layout.bottomMargin: 14
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: 4
                color: yesMa.containsMouse ? "#374151" : "#1f2937"

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
                radius: 4
                color: noMa.containsMouse ? "#f0f0f0" : "#ffffff"
                border.color: "#e5e7eb"
                border.width: 1

                Label {
                    anchors.centerIn: parent
                    text: "No, stop"
                    font.pixelSize: 14
                    color: "#6b7280"
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
            color: checkInDialog.secondsLeft <= 60 ? "#ef4444" : "#9ca3af"
        }
    }
}
