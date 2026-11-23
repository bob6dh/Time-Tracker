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
                    color: backMa.containsMouse ? "#0f172a" : "#64748b"

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
                    color: "#0f172a"
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
                        radius: 10
                        color: "#ffffff"
                        border.color: "#e2e8f0"
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
                                    color: "#0f172a"
                                    Layout.fillWidth: true
                                }
                                Label {
                                    text: time
                                    font.pixelSize: 14
                                    font.features: { "tnum": 1 }
                                    font.weight: Font.DemiBold
                                    color: "#64748b"
                                }
                            }

                            Label {
                                text: description || "No summary"
                                font.pixelSize: 13
                                color: description ? "#64748b" : "#94a3b8"
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
