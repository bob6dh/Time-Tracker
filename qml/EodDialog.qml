import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: eodDialog
    title: "End of Day Summary"
    anchors.centerIn: parent
    modal: true
    width: 400
    height: Math.min(200 + eodRepeater.count * 90, 520)
    closePolicy: Popup.NoAutoClose

    onAboutToShow: backend.eodModel.load()

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        Label {
            text: "End of Day Summary"
            font.pixelSize: 16
            font.bold: true
            color: "#1f2937"
        }

        Label {
            text: "What did you work on today?"
            font.pixelSize: 13
            color: "#6b7280"
            Layout.bottomMargin: 10
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: eodCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: eodCol
                width: parent.width
                spacing: 6

                Repeater {
                    id: eodRepeater
                    model: backend.eodModel

                    ColumnLayout {
                        required property string project
                        required property string description
                        required property int index

                        Layout.fillWidth: true
                        spacing: 2

                        Label {
                            text: project
                            font.pixelSize: 13
                            font.bold: true
                            color: "#1f2937"
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 50
                            radius: 4
                            color: "#f5f5f5"
                            border.color: "#e5e7eb"
                            border.width: 1

                            ScrollView {
                                anchors.fill: parent
                                anchors.margins: 6

                                TextArea {
                                    id: descInput
                                    text: description
                                    font.pixelSize: 13
                                    color: "#1f2937"
                                    wrapMode: TextEdit.WordWrap
                                    background: null

                                    onTextChanged: backend.eodModel.setDescription(index, text)
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: 4
                color: saveMa.containsMouse ? "#374151" : "#1f2937"

                Label {
                    anchors.centerIn: parent
                    text: "Save"
                    font.pixelSize: 14
                    color: "white"
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

            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: 4
                color: laterMa.containsMouse ? "#f0f0f0" : "#ffffff"
                border.color: "#e5e7eb"
                border.width: 1

                Label {
                    anchors.centerIn: parent
                    text: "Later"
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
        }
    }
}
