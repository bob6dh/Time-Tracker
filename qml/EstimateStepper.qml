import QtQuick
import QtQuick.Controls

// Compact "− 1.5h +" stepper for a task time estimate, styled to match the
// app's flat buttons instead of a native SpinBox. Steps in half-hours.
Row {
    id: root
    spacing: 6

    property int estimateMinutes: 30
    readonly property int stepMinutes: 30
    readonly property int minMinutes: 0
    readonly property int maxMinutes: 480

    function label() {
        var h = root.estimateMinutes / 60
        return (h % 1 === 0 ? h.toFixed(0) : h.toFixed(1)) + "h"
    }

    Rectangle {
        width: 26; height: 26; radius: 13
        color: minusMa.containsMouse ? "#f1f5f9" : "#ffffff"
        border.color: "#e2e8f0"; border.width: 1
        anchors.verticalCenter: parent.verticalCenter

        Label {
            anchors.centerIn: parent
            text: "−"
            font.pixelSize: 14
            color: "#64748b"
        }
        MouseArea {
            id: minusMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.estimateMinutes = Math.max(root.minMinutes, root.estimateMinutes - root.stepMinutes)
        }
    }

    Label {
        text: root.label()
        font.pixelSize: 13
        color: "#0f172a"
        width: 34
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
    }

    Rectangle {
        width: 26; height: 26; radius: 13
        color: plusMa.containsMouse ? "#f1f5f9" : "#ffffff"
        border.color: "#e2e8f0"; border.width: 1
        anchors.verticalCenter: parent.verticalCenter

        Label {
            anchors.centerIn: parent
            text: "+"
            font.pixelSize: 14
            color: "#64748b"
        }
        MouseArea {
            id: plusMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.estimateMinutes = Math.min(root.maxMinutes, root.estimateMinutes + root.stepMinutes)
        }
    }
}
