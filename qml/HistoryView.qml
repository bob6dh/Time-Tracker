import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    signal daySelected(string dayKey)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: histCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: histCol
                width: parent.width
                spacing: 6

                // Empty state
                Label {
                    text: "No history yet"
                    font.pixelSize: 14
                    color: "#adb5bd"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 30
                    visible: historyRepeater.count === 0
                }

                Repeater {
                    id: historyRepeater
                    model: backend.historyModel

                    Rectangle {
                        required property string dateKey
                        required property string dateLabel
                        required property string projectCount
                        required property string totalTime
                        required property int index

                        Layout.fillWidth: true
                        height: histRow.implicitHeight + 24
                        radius: 6
                        color: histItemMa.containsMouse ? "#f9fafb" : "#ffffff"
                        border.color: "#e5e7eb"
                        border.width: 1

                        MouseArea {
                            id: histItemMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: daySelected(dateKey)
                        }

                        RowLayout {
                            id: histRow
                            anchors.fill: parent
                            anchors.margins: 14

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Label {
                                    text: dateLabel
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: "#1f2937"
                                }
                                Label {
                                    text: projectCount
                                    font.pixelSize: 12
                                    color: "#6b7280"
                                }
                            }

                            Label {
                                text: totalTime
                                font.pixelSize: 14
                                font.family: "Consolas"
                                color: "#6b7280"
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
