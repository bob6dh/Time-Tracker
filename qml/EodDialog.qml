import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: eodDialog
    anchors.centerIn: parent
    modal: true
    width: 460
    height: Math.min(eodContent.implicitHeight + 2, 600)
    closePolicy: Popup.NoAutoClose
    padding: 0

    onAboutToShow: backend.eodModel.load()

    readonly property var colorPalette: [
        "#4a86c8", "#e07b54", "#5cb85c", "#9b59b6",
        "#e67e22", "#1abc9c", "#e74c3c", "#f39c12"
    ]

    background: Rectangle {
        radius: 10
        color: "#ffffff"
        border.color: "#e5e7eb"
        border.width: 1
        layer.enabled: true
        layer.effect: null
    }

    contentItem: ColumnLayout {
        id: eodContent
        spacing: 0

        // ── Header ───────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: headerCol.implicitHeight + 28
            color: "#1f2937"
            radius: 10

            // Square off the bottom corners
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 10
                color: "#1f2937"
            }

            ColumnLayout {
                id: headerCol
                anchors { left: parent.left; right: parent.right; top: parent.top
                          margins: 20; topMargin: 20 }
                spacing: 4

                Label {
                    text: "End of Day"
                    font.pixelSize: 22
                    font.bold: true
                    color: "#f9fafb"
                }
                Label {
                    text: Qt.formatDate(new Date(), "dddd, MMMM d")
                    font.pixelSize: 13
                    color: "#9ca3af"
                }
                Label {
                    text: "Add notes on what you worked on today"
                    font.pixelSize: 13
                    color: "#6b7280"
                    Layout.topMargin: 2
                }
            }
        }

        // ── Project cards ────────────────────────────────────────
        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(eodProjectCol.implicitHeight + 24, 380)
            contentHeight: eodProjectCol.implicitHeight + 24
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            ColumnLayout {
                id: eodProjectCol
                width: parent.width
                spacing: 10
                anchors { left: parent.left; right: parent.right; top: parent.top
                          margins: 16; topMargin: 16 }

                Repeater {
                    id: eodRepeater
                    model: backend.eodModel

                    Rectangle {
                        required property string project
                        required property string description
                        required property string timeText
                        required property int index

                        // Compute once here; children reference projColor instead of
                        // re-evaluating the palette lookup (avoids undefined QColor errors)
                        readonly property var projColor:
                            (eodDialog.colorPalette && index >= 0)
                                ? eodDialog.colorPalette[index % eodDialog.colorPalette.length]
                                : "#4a86c8"

                        Layout.fillWidth: true
                        implicitHeight: cardInner.implicitHeight + 24
                        radius: 8
                        color: "#f9fafb"
                        border.color: "#e5e7eb"
                        border.width: 1

                        // Left colour accent
                        Rectangle {
                            width: 4
                            height: parent.height - 16
                            anchors.left: parent.left
                            anchors.leftMargin: 0
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 2
                            color: projColor
                        }

                        ColumnLayout {
                            id: cardInner
                            anchors { left: parent.left; right: parent.right; top: parent.top
                                      leftMargin: 16; rightMargin: 12; topMargin: 12 }
                            spacing: 8

                            // Project name + time badge
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Label {
                                    text: project
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: "#1f2937"
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    implicitWidth: timeBadge.implicitWidth + 12
                                    implicitHeight: timeBadge.implicitHeight + 6
                                    radius: 4
                                    color: projColor
                                    opacity: 0.15

                                    Label {
                                        id: timeBadge
                                        anchors.centerIn: parent
                                        text: timeText
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: projColor
                                        opacity: 1 / parent.opacity
                                    }
                                }
                            }

                            // Description text area
                            Rectangle {
                                Layout.fillWidth: true
                                height: 72
                                radius: 6
                                color: noteArea.activeFocus ? "#f0f4ff" : "#ffffff"
                                border.color: noteArea.activeFocus ? "#93c5fd" : "#e5e7eb"
                                border.width: 1

                                Flickable {
                                    anchors { fill: parent; margins: 8 }
                                    contentHeight: noteArea.implicitHeight
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    flickableDirection: Flickable.VerticalFlick

                                    TextEdit {
                                        id: noteArea
                                        width: parent.width
                                        text: description
                                        font.pixelSize: 13
                                        color: "#1f2937"
                                        wrapMode: TextEdit.Wrap
                                        selectByMouse: true

                                        Text {
                                            text: "What did you accomplish on this project today?"
                                            color: "#d1d5db"
                                            font.pixelSize: 13
                                            visible: !noteArea.text && !noteArea.activeFocus
                                        }

                                        onTextChanged: backend.eodModel.setDescription(index, text)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Buttons ──────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.bottomMargin: 16
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                height: 42
                radius: 6
                color: laterMa.containsMouse ? "#f3f4f6" : "#ffffff"
                border.color: "#e5e7eb"
                border.width: 1

                Label {
                    anchors.centerIn: parent
                    text: "Remind me later"
                    font.pixelSize: 14
                    color: "#6b7280"
                }
                MouseArea {
                    id: laterMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        backend.dismissEod()
                        eodDialog.close()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 42
                radius: 6
                color: saveMa.containsMouse ? "#374151" : "#1f2937"

                Label {
                    anchors.centerIn: parent
                    text: "Save Notes"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#f9fafb"
                }
                MouseArea {
                    id: saveMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        backend.saveEod()
                        eodDialog.close()
                    }
                }
            }
        }
    }
}
