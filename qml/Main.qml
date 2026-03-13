import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    visible: true
    width: 480
    height: 680
    minimumWidth: 420
    minimumHeight: 550
    title: "Time Tracker"
    color: "#f5f5f5"

    property string currentView: "timer"
    property string selectedDay: ""

    CheckInDialog {
        id: checkInDialog
    }

    EodDialog {
        id: eodDialog
    }

    Connections {
        target: backend
        function onShowCheckIn() { checkInDialog.open() }
        function onShowEod() { eodDialog.open() }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 0

        // Header
        Label {
            text: "Time Tracker"
            font.pixelSize: 24
            font.bold: true
            color: "#1f2937"
            Layout.bottomMargin: 10
        }

        // Navigation
        RowLayout {
            spacing: 6
            Layout.bottomMargin: 10

            Repeater {
                model: ["timer", "history", "reports", "settings"]

                Rectangle {
                    required property string modelData
                    required property int index
                    width: navLabel.implicitWidth + 28
                    height: navLabel.implicitHeight + 10
                    radius: 4
                    color: root.currentView === modelData ? "#1f2937" : "#ffffff"
                    border.color: "#e5e7eb"
                    border.width: root.currentView === modelData ? 0 : 1

                    Label {
                        id: navLabel
                        anchors.centerIn: parent
                        text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                        font.pixelSize: 14
                        color: root.currentView === modelData ? "#ffffff" : "#6b7280"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.currentView = modelData
                            root.selectedDay = ""
                        }
                    }
                }
            }
        }

        // Content area
        StackLayout {
            id: contentStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.currentView === "timer" ? 0
                        : root.currentView === "history" ? 1
                        : root.currentView === "reports" ? 2 : 3

            TimerView {}

            // History + Day detail share index 1
            Item {
                StackLayout {
                    anchors.fill: parent
                    currentIndex: root.selectedDay === "" ? 0 : 1

                    HistoryView {
                        onDaySelected: function(dayKey) {
                            root.selectedDay = dayKey
                            backend.openDayDetail(dayKey)
                        }
                    }

                    DayDetailView {
                        dayKey: root.selectedDay
                        onBack: root.selectedDay = ""
                    }
                }
            }

            ReportView {}

            SettingsView {}
        }
    }
}
