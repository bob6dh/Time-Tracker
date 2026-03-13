import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: reportView

    Component.onCompleted: backend.refreshReport()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: reportCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: reportCol
                width: parent.width
                spacing: 8

                // Period selector (Day | Week | Month)
                RowLayout {
                    spacing: 6
                    Layout.bottomMargin: 4

                    Repeater {
                        model: ["day", "week", "month"]

                        Rectangle {
                            required property string modelData
                            required property int index
                            width: periodLbl.implicitWidth + 28
                            height: periodLbl.implicitHeight + 10
                            radius: 4
                            color: backend.reportPeriod === modelData ? "#1f2937" : "#ffffff"
                            border.color: "#e5e7eb"
                            border.width: backend.reportPeriod === modelData ? 0 : 1

                            Label {
                                id: periodLbl
                                anchors.centerIn: parent
                                text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                font.pixelSize: 14
                                color: backend.reportPeriod === modelData ? "#ffffff" : "#6b7280"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: backend.setReportPeriod(modelData)
                            }
                        }
                    }
                }

                // Navigation (< label >)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        width: 36
                        height: 36
                        radius: 4
                        color: prevMa.containsMouse ? "#f0f0f0" : "#ffffff"
                        border.color: "#e5e7eb"
                        border.width: 1

                        Label {
                            anchors.centerIn: parent
                            text: "\u2190"
                            font.pixelSize: 16
                            color: "#6b7280"
                        }
                        MouseArea {
                            id: prevMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.reportPrev()
                        }
                    }

                    Label {
                        text: backend.reportLabel
                        font.pixelSize: 15
                        font.bold: true
                        color: "#1f2937"
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        width: 36
                        height: 36
                        radius: 4
                        color: nextMa.containsMouse ? "#f0f0f0" : "#ffffff"
                        border.color: "#e5e7eb"
                        border.width: 1

                        Label {
                            anchors.centerIn: parent
                            text: "\u2192"
                            font.pixelSize: 16
                            color: "#6b7280"
                        }
                        MouseArea {
                            id: nextMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.reportNext()
                        }
                    }
                }

                // Total time card
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: totalCol.implicitHeight + 24
                    radius: 6
                    color: "#eef4ff"
                    border.color: "#93c5fd"
                    border.width: 1

                    ColumnLayout {
                        id: totalCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 2

                        Label {
                            text: "Total Time"
                            font.pixelSize: 12
                            color: "#6b7280"
                        }
                        Label {
                            text: backend.reportTotal
                            font.pixelSize: 28
                            font.family: "Consolas"
                            font.bold: true
                            color: "#1f2937"
                        }
                    }
                }

                // Empty state
                Label {
                    text: "No time tracked for this period"
                    font.pixelSize: 14
                    color: "#adb5bd"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 20
                    visible: reportRepeater.count === 0
                }

                // Project breakdown
                Repeater {
                    id: reportRepeater
                    model: backend.reportModel

                    Rectangle {
                        required property string project
                        required property string time
                        required property int seconds
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: reportItemCol.implicitHeight + 24
                        radius: 6
                        color: "#ffffff"
                        border.color: "#e5e7eb"
                        border.width: 1

                        ColumnLayout {
                            id: reportItemCol
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true

                                Label {
                                    text: project
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: "#1f2937"
                                    Layout.fillWidth: true
                                }
                                Label {
                                    text: time
                                    font.pixelSize: 14
                                    font.family: "Consolas"
                                    color: "#6b7280"
                                }
                            }

                            // Progress bar
                            Rectangle {
                                Layout.fillWidth: true
                                height: 6
                                radius: 3
                                color: "#f3f4f6"

                                Rectangle {
                                    width: {
                                        var total = backend.reportTotalSeconds
                                        if (total <= 0) return 0
                                        return parent.width * (seconds / total)
                                    }
                                    height: parent.height
                                    radius: 3
                                    color: {
                                        var colors = ["#3b82f6", "#10b981", "#f59e0b", "#ef4444", "#8b5cf6", "#ec4899"]
                                        return colors[index % colors.length]
                                    }
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
