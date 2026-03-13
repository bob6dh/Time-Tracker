import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: dayDetail
    property string dayKey: ""
    signal back()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: detailCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: detailCol
                width: parent.width
                spacing: 6

                // Back button
                Label {
                    text: "\u2190 Back"
                    font.pixelSize: 14
                    color: backMa.containsMouse ? "#1f2937" : "#6b7280"

                    MouseArea {
                        id: backMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dayDetail.back()
                    }
                }

                // Day title
                Label {
                    text: dayKey !== "" ? backend.dayDetailTitle(dayKey) : ""
                    font.pixelSize: 20
                    font.bold: true
                    color: "#1f2937"
                    Layout.bottomMargin: 10
                }

                Repeater {
                    model: backend.dayDetailModel

                    Rectangle {
                        required property string project
                        required property string time
                        required property string description
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: detailItemCol.implicitHeight + 24
                        radius: 6
                        color: "#ffffff"
                        border.color: "#e5e7eb"
                        border.width: 1

                        ColumnLayout {
                            id: detailItemCol
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 4

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

                            Label {
                                text: description || "No summary"
                                font.pixelSize: 13
                                color: description ? "#6b7280" : "#adb5bd"
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                Layout.topMargin: 2
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
