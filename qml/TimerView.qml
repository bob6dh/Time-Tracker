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

                // ── Daily / weekly / monthly summary ─────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: summaryRow.implicitHeight + 20
                    radius: 6
                    color: "#1f2937"

                    Row {
                        id: summaryRow
                        anchors.centerIn: parent
                        width: parent.width - 24
                        spacing: 0

                        Repeater {
                            model: [
                                { label: "Today",      value: backend.todayTotal },
                                { label: "This Week",  value: backend.weekTotal  },
                                { label: "This Month", value: backend.monthTotal  }
                            ]

                            Item {
                                required property var modelData
                                required property int index
                                width: summaryRow.width / 3
                                height: summaryCol.implicitHeight

                                // Divider between cells (not before the first)
                                Rectangle {
                                    visible: index > 0
                                    x: 0; y: 4
                                    width: 1
                                    height: parent.height - 8
                                    color: "#374151"
                                }

                                ColumnLayout {
                                    id: summaryCol
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Label {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.value
                                        font.pixelSize: 18
                                        font.bold: true
                                        color: "#f9fafb"
                                    }
                                    Label {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.label
                                        font.pixelSize: 11
                                        color: "#9ca3af"
                                    }
                                }
                            }
                        }
                    }
                }

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

                ProjectDialog { id: projectDialog }
                ConfirmRemoveDialog { id: confirmRemoveDialog }

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
                        required property bool   isActive
                        required property int    index
                        required property string billingCode
                        required property bool   billable

                        Layout.fillWidth: true
                        height: 70
                        radius: 6
                        color: isActive ? "#eef4ff" : "#ffffff"
                        border.color: isActive ? "#93c5fd" : "#e5e7eb"
                        border.width: 1

                        Item {
                            id: projRow
                            anchors.fill: parent
                            anchors.margins: 14

                            // Remove button — anchored to far right
                            Label {
                                id: removeBtn
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\u2715"
                                font.pixelSize: 15
                                color: removeMa.containsMouse ? "#ef4444" : "#d1d5db"

                                MouseArea {
                                    id: removeMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                    confirmRemoveDialog.projectName = name
                                    confirmRemoveDialog.open()
                                }
                                }
                            }

                            // Active badge or Start button — anchored just left of remove button
                            Rectangle {
                                id: actionBtn
                                anchors.right: removeBtn.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: isActive ? (activeLbl.implicitWidth + 20) : (startRow.implicitWidth + 24)
                                height: 34
                                radius: 17
                                color: isActive ? "#dbeafe" : "transparent"
                                border.color: isActive ? "#93c5fd" : "transparent"
                                border.width: isActive ? 1 : 0

                                gradient: isActive ? null : startGradient

                                Gradient {
                                    id: startGradient
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: startMa.containsMouse ? "#15803d" : "#16a34a" }
                                    GradientStop { position: 1.0; color: startMa.containsMouse ? "#166534" : "#15803d" }
                                }

                                Label {
                                    id: activeLbl
                                    anchors.centerIn: parent
                                    visible: isActive
                                    text: "● Active"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#2563eb"
                                }

                                Row {
                                    id: startRow
                                    anchors.centerIn: parent
                                    visible: !isActive
                                    spacing: 5

                                    Label {
                                        text: "\u25B6"
                                        font.pixelSize: 10
                                        color: "white"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Label {
                                        text: "Start"
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: "white"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: startMa
                                    anchors.fill: parent
                                    enabled: !isActive
                                    hoverEnabled: true
                                    cursorShape: isActive ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: if (!isActive) backend.startProject(name)
                                }
                            }

                            // Project info — anchored left, right edge stops at action button
                            ColumnLayout {
                                anchors.left: parent.left
                                anchors.right: actionBtn.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                Label {
                                    text: name
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: isActive ? "#2563eb" : "#1f2937"
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                // Billing info + today time row
                                Row {
                                    spacing: 6

                                    // Billable badge
                                    Rectangle {
                                        height: 16; radius: 3
                                        width: billableLbl.implicitWidth + 8
                                        color: billable ? "#dcfce7" : "#f3f4f6"

                                        Label {
                                            id: billableLbl
                                            anchors.centerIn: parent
                                            text: billable ? "$ Billable" : "Non-billable"
                                            font.pixelSize: 10
                                            color: billable ? "#16a34a" : "#9ca3af"
                                        }
                                    }

                                    // Billing code tag (only if set)
                                    Rectangle {
                                        visible: billingCode !== ""
                                        height: 16; radius: 3
                                        width: codeLabel.implicitWidth + 8
                                        color: "#f0f4ff"

                                        Label {
                                            id: codeLabel
                                            anchors.centerIn: parent
                                            text: billingCode
                                            font.pixelSize: 10
                                            color: "#4a86c8"
                                        }
                                    }

                                    Label {
                                        text: "· Today: " + todayTime
                                        font.pixelSize: 11
                                        color: "#9ca3af"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
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

                // New Project button
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 4
                    color: newProjMa.containsMouse ? "#374151" : "#1f2937"
                    Layout.topMargin: 6

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Label {
                            text: "+"
                            font.pixelSize: 18
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Label {
                            text: "New Project"
                            font.pixelSize: 14
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: newProjMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: projectDialog.open()
                    }
                }

                // Bottom spacer
                Item { Layout.fillHeight: true }
            }
        }
    }
}
