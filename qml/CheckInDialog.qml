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
    }
}
