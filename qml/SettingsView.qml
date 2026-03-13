import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: settingsCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: settingsCol
                width: parent.width
                spacing: 0

                Label {
                    text: "Check-in Interval"
                    font.pixelSize: 20
                    font.bold: true
                    color: "#1f2937"
                    Layout.bottomMargin: 4
                }

                Label {
                    text: "How often should we check if you're\nstill on the same project?"
                    font.pixelSize: 14
                    color: "#6b7280"
                    Layout.bottomMargin: 12
                }

                RowLayout {
                    spacing: 8
                    Layout.bottomMargin: 24

                    Repeater {
                        model: [15, 30, 60]

                        Rectangle {
                            required property int modelData
                            required property int index
                            property bool selected: backend.checkInInterval === modelData

                            width: 80
                            height: 40
                            radius: 4
                            color: selected ? "#1f2937"
                                 : intervalMa.containsMouse ? "#f0f0f0" : "#ffffff"
                            border.color: "#e5e7eb"
                            border.width: selected ? 0 : 1

                            Label {
                                anchors.centerIn: parent
                                text: modelData === 60 ? "1 hour" : modelData + " min"
                                font.pixelSize: 14
                                color: selected ? "#ffffff" : "#6b7280"
                            }

                            MouseArea {
                                id: intervalMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: backend.setCheckInInterval(modelData)
                            }
                        }
                    }
                }

                Label {
                    text: "Data"
                    font.pixelSize: 20
                    font.bold: true
                    color: "#1f2937"
                    Layout.bottomMargin: 8
                }

                Rectangle {
                    width: clearLabel.implicitWidth + 28
                    height: 40
                    radius: 4
                    color: clearMa.containsMouse ? "#fee2e2" : "#fff0f0"
                    border.color: "#fecaca"
                    border.width: 1

                    Label {
                        id: clearLabel
                        anchors.centerIn: parent
                        text: "Clear all history"
                        font.pixelSize: 14
                        color: "#ef4444"
                    }

                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clearConfirmDialog.open()
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    Dialog {
        id: clearConfirmDialog
        title: "Clear History"
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Yes | Dialog.No

        Label {
            text: "Clear all history? This cannot be undone."
            font.pixelSize: 14
        }

        onAccepted: backend.clearHistory()
    }
}
