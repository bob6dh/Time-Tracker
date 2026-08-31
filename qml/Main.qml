import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform as Platform

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

    // Closing the window minimizes to tray instead of quitting — the timer,
    // check-ins, idle detection etc. all keep running in the background.
    // Quit is only reachable from the tray menu.
    onClosing: function(close) {
        close.accepted = false
        root.hide()
    }

    CheckInWindow {
        id: checkInWindow
    }

    EodDialog {
        id: eodDialog
    }

    Connections {
        target: backend
        function onShowCheckIn() { checkInWindow.showWindow() }
        function onShowEod() { eodDialog.open() }
    }

    Platform.SystemTrayIcon {
        id: trayIcon
        visible: true
        icon.source: "../time_img.ico"
        tooltip: backend.activeProject !== ""
                 ? "Time Tracker — " + backend.activeProject + " (" + backend.elapsedText + ")"
                 : "Time Tracker"

        onActivated: function(reason) {
            if (reason === Platform.SystemTrayIcon.Trigger || reason === Platform.SystemTrayIcon.DoubleClick) {
                if (root.visible) {
                    root.hide()
                } else {
                    root.show()
                    root.raise()
                    root.requestActivate()
                }
            }
        }

        menu: Platform.Menu {
            Platform.MenuItem {
                text: "Show Time Tracker"
                onTriggered: { root.show(); root.raise(); root.requestActivate() }
            }
            Platform.MenuItem {
                text: "Stop Timer"
                visible: backend.activeProject !== ""
                onTriggered: backend.stopTimer()
            }
            Platform.MenuSeparator {}
            Platform.MenuItem {
                text: "Quit"
                onTriggered: Qt.quit()
            }
        }
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
                model: ["timer", "tasks", "history", "reports", "settings"]

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
                        : root.currentView === "tasks" ? 1
                        : root.currentView === "history" ? 2
                        : root.currentView === "reports" ? 3 : 4

            TimerView {}

            TaskListView {}

            // History + Day detail share index 2
            Item {
                StackLayout {
                    anchors.fill: parent
                    currentIndex: root.selectedDay === "" ? 0 : 1

                    HistoryView {
                        onDaySelected: function(dayKey) {
                            root.selectedDay = dayKey
                        }
                    }

                    TimeEditView {
                        dayKey: root.selectedDay
                        onBack: root.selectedDay = ""
                        onSaved: root.selectedDay = ""
                    }
                }
            }

            ReportView {}

            SettingsView {}
        }
    }
}
