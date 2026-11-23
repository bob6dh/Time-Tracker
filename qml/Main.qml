import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform as Platform

// The main window is a frameless tool window: it never gets a taskbar button
// (Qt.Tool), so the app lives only in the system tray / hidden-icons area.
// It's opened from the tray icon and hidden (not closed) when dismissed.
ApplicationWindow {
    id: root
    visible: false
    width: 480
    height: 700
    minimumWidth: 420
    minimumHeight: 550
    title: "Time Tracker"
    flags: Qt.Tool | Qt.FramelessWindowHint
    color: "transparent"

    property string currentView: "timer"
    property string selectedDay: ""
    property bool positioned: false

    // Place the window just above the tray (bottom-right of the primary
    // screen's work area) the first time it's shown; after that it stays
    // wherever the user dragged it.
    function showWindow() {
        if (!positioned) {
            var g = backend.primaryAvailableGeometry()
            x = g.x + g.width - width - 16
            y = g.y + g.height - height - 16
            positioned = true
        }
        show()
        raise()
        requestActivate()
    }

    Component.onCompleted: {
        // First launch of the day: open straight to Today's Plan. Otherwise
        // start quietly in the tray.
        if (backend.checkAndMarkDailyOpen()) {
            root.currentView = "tasks"
            root.showWindow()
        } else {
            startupToast.start()
        }
    }

    Timer {
        id: startupToast
        interval: 800
        onTriggered: trayIcon.showMessage("Time Tracker is running",
                                          "It lives in the system tray — click the icon to open it.",
                                          Platform.SystemTrayIcon.Information, 4000)
    }

    onClosing: function(close) {
        close.accepted = false
        root.hide()
    }

    CheckInWindow { id: checkInWindow }
    ActivityPrompt {
        id: activityPrompt
        onOpenAppRequested: root.showWindow()
    }
    EodDialog { id: eodDialog }

    Connections {
        target: backend
        function onShowCheckIn() { checkInWindow.showWindow() }
        function onShowEod() {
            // The EOD dialog lives inside this window, so bring it up first —
            // otherwise it would open invisibly while we're hidden in the tray.
            root.showWindow()
            eodDialog.open()
        }
        function onShowActivityPrompt() {
            // Already looking at the app — they can pick here; ask again later.
            if (root.visible && root.active) {
                backend.snoozeActivityPrompt(1)
                return
            }
            activityPrompt.showPrompt()
        }
    }

    Platform.SystemTrayIcon {
        id: trayIcon
        visible: true
        // Must be resolved to an absolute URL: Qt.labs.platform does not resolve a
        // bare relative path, the icon ends up empty, and Windows then never adds
        // the tray icon at all (app runs with no visible icon anywhere).
        icon.source: Qt.resolvedUrl("../time_img.ico")
        tooltip: backend.activeProject !== ""
                 ? "Time Tracker — " + backend.activeProject + " (" + backend.elapsedText + ")"
                 : "Time Tracker — not tracking"

        onActivated: function(reason) {
            if (reason === Platform.SystemTrayIcon.Trigger || reason === Platform.SystemTrayIcon.DoubleClick) {
                if (root.visible) root.hide()
                else root.showWindow()
            }
        }

        menu: Platform.Menu {
            Platform.MenuItem {
                text: "Open Time Tracker"
                onTriggered: root.showWindow()
            }
            Platform.MenuItem {
                text: "What am I working on?"
                visible: backend.activeProject === ""
                onTriggered: activityPrompt.showPrompt()
            }
            Platform.MenuItem {
                text: "Stop Timer (" + backend.activeProject + ")"
                visible: backend.activeProject !== ""
                onTriggered: backend.stopTimer()
            }
            Platform.MenuItem {
                text: "Pause prompts for 1 hour"
                visible: backend.activityPromptEnabled
                onTriggered: backend.snoozeActivityPrompt(60)
            }
            Platform.MenuSeparator {}
            Platform.MenuItem {
                text: "Quit"
                // Qt.exit, not Qt.quit: in Qt 6 quit() first asks every window
                // to close and is cancelled if one refuses — and this window
                // always refuses (✕ hides to tray), so Quit would silently do
                // nothing while the window is open.
                onTriggered: Qt.exit(0)
            }
        }
    }

    // ── Window chrome ───────────────────────────────────────────────
    Rectangle {
        id: frame
        anchors.fill: parent
        radius: 14
        color: "#f4f5f9"
        border.color: "#dfe3ec"
        border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 1
            spacing: 0

            // Title bar — drag to move; ✕ / — hide to tray.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 52

                DragHandler {
                    target: null
                    onActiveChanged: if (active) root.startSystemMove()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 10
                    spacing: 10

                    Rectangle {
                        width: 26; height: 26; radius: 8
                        color: "#4f46e5"
                        Label {
                            anchors.centerIn: parent
                            text: "⏱"
                            color: "white"
                            font.pixelSize: 14
                        }
                    }
                    Label {
                        text: "Time Tracker"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        color: "#0f172a"
                    }

                    // Live status pill
                    Rectangle {
                        visible: backend.activeProject !== ""
                        Layout.leftMargin: 4
                        height: 24; radius: 12
                        width: statusRow.implicitWidth + 18
                        color: "#ecfdf5"
                        border.color: "#a7f3d0"
                        Row {
                            id: statusRow
                            anchors.centerIn: parent
                            spacing: 6
                            Rectangle {
                                width: 7; height: 7; radius: 4
                                color: "#10b981"
                                anchors.verticalCenter: parent.verticalCenter
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    running: backend.activeProject !== ""
                                    NumberAnimation { to: 0.3; duration: 900 }
                                    NumberAnimation { to: 1.0; duration: 900 }
                                }
                            }
                            Label {
                                text: backend.elapsedText
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: "#047857"
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Repeater {
                        model: ["–", "✕"]
                        Rectangle {
                            required property string modelData
                            width: 32; height: 32; radius: 8
                            color: chromeMa.containsMouse ? "#e2e8f0" : "transparent"
                            Label {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: 14
                                color: "#475569"
                            }
                            MouseArea {
                                id: chromeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.hide()
                            }
                            ToolTip.visible: chromeMa.containsMouse
                            ToolTip.delay: 600
                            ToolTip.text: "Hide to tray"
                        }
                    }
                }
            }

            // Segmented navigation
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 18
                Layout.rightMargin: 18
                Layout.bottomMargin: 14
                height: 40
                radius: 11
                color: "#e8ebf2"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4

                    Repeater {
                        model: ["timer", "tasks", "history", "reports", "settings"]

                        Rectangle {
                            required property string modelData
                            property bool current: root.currentView === modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 8
                            color: current ? "#ffffff" : navMa.containsMouse ? "#f1f3f8" : "transparent"
                            border.color: current ? "#dfe3ec" : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Label {
                                anchors.centerIn: parent
                                text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                font.pixelSize: 13
                                font.weight: current ? Font.DemiBold : Font.Normal
                                color: current ? "#0f172a" : "#64748b"
                            }

                            MouseArea {
                                id: navMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.currentView = modelData
                                    root.selectedDay = ""
                                }
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
                Layout.leftMargin: 18
                Layout.rightMargin: 18
                Layout.bottomMargin: 14
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

        // Resize grip (frameless windows have no OS border to drag)
        Item {
            width: 18; height: 18
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            Label {
                anchors.centerIn: parent
                text: "◢"
                font.pixelSize: 10
                color: "#cbd5e1"
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeFDiagCursor
                acceptedButtons: Qt.NoButton
            }
            DragHandler {
                target: null
                onActiveChanged: if (active) root.startSystemResize(Qt.RightEdge | Qt.BottomEdge)
            }
        }
    }
}
