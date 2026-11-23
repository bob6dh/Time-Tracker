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
                    radius: 10
                    color: "#0f172a"

                    Row {
                        id: summaryRow
                        anchors.centerIn: parent
                        width: parent.width - 24
                        spacing: 0

                        Repeater {
                            model: [
                                { label: "Today",      value: backend.todayTotal,  billable: backend.todayBillable  },
                                { label: "This Week",  value: backend.weekTotal,   billable: backend.weekBillable   },
                                { label: "This Month", value: backend.monthTotal,  billable: backend.monthBillable  }
                            ]

                            Item {
                                required property var modelData
                                width: summaryRow.width / 3
                                height: summaryCol.implicitHeight

                                ColumnLayout {
                                    id: summaryCol
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Label {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.value
                                        font.pixelSize: 18
                                        font.bold: true
                                        color: "#f8fafc"
                                    }
                                    Label {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.billable + " billable"
                                        font.pixelSize: 11
                                        color: "#6ee7b7"
                                    }
                                    Label {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.label
                                        font.pixelSize: 11
                                        color: "#94a3b8"
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
                    radius: 10
                    color: "#eef2ff"
                    border.color: "#c7d2fe"
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
                            color: "#64748b"
                        }
                        Label {
                            text: backend.activeProject
                            font.pixelSize: 20
                            font.bold: true
                            color: "#0f172a"
                        }
                        Label {
                            visible: backend.activeTaskTitle !== ""
                            text: "on: " + backend.activeTaskTitle
                            font.pixelSize: 13
                            color: "#64748b"
                        }
                        Label {
                            text: backend.elapsedText
                            font.pixelSize: 36
                            font.features: { "tnum": 1 }
                            font.weight: Font.DemiBold
                            color: "#0f172a"
                            Layout.topMargin: 4
                            Layout.bottomMargin: 10
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: 8
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
                    color: "#94a3b8"
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
                        radius: 10
                        color: isActive ? "#eef2ff" : "#ffffff"
                        border.color: isActive ? "#c7d2fe" : "#e2e8f0"
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
                                color: removeMa.containsMouse ? "#ef4444" : "#cbd5e1"

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
                                color: isActive ? "#e0e7ff" : "transparent"
                                border.color: isActive ? "#c7d2fe" : "transparent"
                                border.width: isActive ? 1 : 0

                                gradient: isActive ? null : startGradient

                                Gradient {
                                    id: startGradient
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: startMa.containsMouse ? "#4338ca" : "#4f46e5" }
                                    GradientStop { position: 1.0; color: startMa.containsMouse ? "#4338ca" : "#4f46e5" }
                                }

                                Label {
                                    id: activeLbl
                                    anchors.centerIn: parent
                                    visible: isActive
                                    text: "● Active"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#4f46e5"
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
                                    color: isActive ? "#4f46e5" : "#0f172a"
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                // Billing info + today time row
                                Row {
                                    spacing: 6

                                    // Billable badge
                                    Rectangle {
                                        height: 16; radius: 5
                                        width: billableLbl.implicitWidth + 8
                                        color: billable ? "#d1fae5" : "#f1f5f9"

                                        Label {
                                            id: billableLbl
                                            anchors.centerIn: parent
                                            text: billable ? "$ Billable" : "Non-billable"
                                            font.pixelSize: 10
                                            color: billable ? "#059669" : "#94a3b8"
                                        }
                                    }

                                    // Billing code tag (only if set)
                                    Rectangle {
                                        visible: billingCode !== ""
                                        height: 16; radius: 5
                                        width: codeLabel.implicitWidth + 8
                                        color: "#eef2ff"

                                        Label {
                                            id: codeLabel
                                            anchors.centerIn: parent
                                            text: billingCode
                                            font.pixelSize: 10
                                            color: "#4f46e5"
                                        }
                                    }

                                    Label {
                                        text: "· Today: " + todayTime
                                        font.pixelSize: 11
                                        color: "#94a3b8"
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
                    radius: 8
                    color: eodMa.containsMouse ? "#f1f5f9" : "#ffffff"
                    border.color: "#e2e8f0"
                    border.width: 1
                    visible: backend.hasTodayLogs
                    Layout.topMargin: 8

                    Label {
                        anchors.centerIn: parent
                        text: "Write daily summary"
                        font.pixelSize: 14
                        color: "#64748b"
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
                    radius: 8
                    color: newProjMa.containsMouse ? "#4338ca" : "#4f46e5"
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
