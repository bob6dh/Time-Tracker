import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: timerView

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: innerCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: innerCol
                width: parent.width
                spacing: 6

                // Active timer card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: activeCol.implicitHeight + 24
                    radius: 6
                    color: "#eef4ff"
                    border.color: "#93c5fd"
                    border.width: 1
                    visible: backend.activeProject !== ""

                    ColumnLayout {
                        id: activeCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 2

                        Label {
                            text: "Currently tracking"
                            font.pixelSize: 12
                            color: "#6b7280"
                        }
                        Label {
                            text: backend.activeProject
                            font.pixelSize: 20
                            font.bold: true
                            color: "#1f2937"
                        }
                        Label {
                            text: backend.elapsedText
                            font.pixelSize: 36
                            font.family: "Consolas"
                            color: "#1f2937"
                            Layout.topMargin: 4
                            Layout.bottomMargin: 10
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: 4
                            color: stopMa.containsMouse ? "#dc2626" : "#ef4444"

                            Label {
                                anchors.centerIn: parent
                                text: "Stop"
                                font.pixelSize: 14
                                color: "white"
                            }
                            MouseArea {
                                id: stopMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: backend.stopTimer()
                            }
                        }
                    }
                }

                // Add project row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        radius: 4
                        color: "#ffffff"
                        border.color: "#e5e7eb"
                        border.width: 1

                        TextInput {
                            id: addInput
                            anchors.fill: parent
                            anchors.margins: 10
                            verticalAlignment: TextInput.AlignVCenter
                            font.pixelSize: 14
                            color: "#1f2937"
                            clip: true

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Project name..."
                                color: "#adb5bd"
                                font.pixelSize: 14
                                visible: !addInput.text && !addInput.activeFocus
                            }

                            Keys.onReturnPressed: {
                                if (addInput.text.trim() !== "") {
                                    backend.addProject(addInput.text)
                                    addInput.text = ""
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 60
                        height: 40
                        radius: 4
                        color: addBtnMa.containsMouse ? "#374151" : "#1f2937"

                        Label {
                            anchors.centerIn: parent
                            text: "Add"
                            font.pixelSize: 14
                            color: "white"
                        }
                        MouseArea {
                            id: addBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (addInput.text.trim() !== "") {
                                    backend.addProject(addInput.text)
                                    addInput.text = ""
                                }
                            }
                        }
                    }
                }

                // Empty state
                Label {
                    text: "Add a project to get started"
                    font.pixelSize: 14
                    color: "#adb5bd"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 30
                    visible: projectRepeater.count === 0
                }

                // Project list
                Repeater {
                    id: projectRepeater
                    model: backend.projectModel

                    Rectangle {
                        required property string name
                        required property string todayTime
                        required property bool isActive
                        required property int index

                        Layout.fillWidth: true
                        height: projRow.implicitHeight + 24
                        radius: 6
                        color: isActive ? "#eef4ff" : "#ffffff"
                        border.color: isActive ? "#93c5fd" : "#e5e7eb"
                        border.width: 1

                        RowLayout {
                            id: projRow
                            anchors.fill: parent
                            anchors.margins: 14

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Label {
                                    text: name
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: isActive ? "#2563eb" : "#1f2937"
                                }
                                Label {
                                    text: "Today: " + todayTime
                                    font.pixelSize: 12
                                    color: "#6b7280"
                                }
                            }

                            // Active badge or Start button
                            Rectangle {
                                visible: isActive
                                width: activeLbl.implicitWidth + 16
                                height: activeLbl.implicitHeight + 4
                                radius: 4
                                color: "#dbeafe"

                                Label {
                                    id: activeLbl
                                    anchors.centerIn: parent
                                    text: "Active"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#2563eb"
                                }
                            }

                            Rectangle {
                                visible: !isActive
                                width: startLbl.implicitWidth + 28
                                height: 32
                                radius: 4
                                color: startMa.containsMouse ? "#374151" : "#1f2937"

                                Label {
                                    id: startLbl
                                    anchors.centerIn: parent
                                    text: "Start"
                                    font.pixelSize: 13
                                    color: "white"
                                }
                                MouseArea {
                                    id: startMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: backend.startProject(name)
                                }
                            }

                            // Remove button
                            Label {
                                text: "\u2715"
                                font.pixelSize: 16
                                color: removeMa.containsMouse ? "#ef4444" : "#adb5bd"

                                MouseArea {
                                    id: removeMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: backend.removeProject(name)
                                }
                            }
                        }
                    }
                }

                // Daily summary button
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 4
                    color: eodMa.containsMouse ? "#f0f0f0" : "#ffffff"
                    border.color: "#e5e7eb"
                    border.width: 1
                    visible: backend.hasTodayLogs
                    Layout.topMargin: 8

                    Label {
                        anchors.centerIn: parent
                        text: "Write daily summary"
                        font.pixelSize: 14
                        color: "#6b7280"
                    }
                    MouseArea {
                        id: eodMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.openEodDialog()
                    }
                }

                // Bottom spacer
                Item { Layout.fillHeight: true }
            }
        }
    }
}
