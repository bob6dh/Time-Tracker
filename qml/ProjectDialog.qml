import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: projectDialog
    title: ""
    modal: true
    width: 340
    anchors.centerIn: parent
    closePolicy: Popup.NoAutoClose

    // Reset fields each time the dialog opens
    onAboutToShow: {
        nameField.text = ""
        billingCodeField.text = ""
        billable = true
        nameField.forceActiveFocus()
    }

    property bool billable: true

    background: Rectangle {
        radius: 8
        color: "#ffffff"
        border.color: "#e5e7eb"
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 0

        // Header
        Label {
            text: "New Project"
            font.pixelSize: 18
            font.bold: true
            color: "#1f2937"
            Layout.bottomMargin: 18
        }

        // ── Name ─────────────────────────────────────────────────
        Label {
            text: "Project Name"
            font.pixelSize: 12
            color: "#6b7280"
            Layout.bottomMargin: 4
        }
        Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: 4
            color: "#ffffff"
            border.color: nameField.activeFocus ? "#2563eb" : "#e5e7eb"
            border.width: 1
            Layout.bottomMargin: 14

            TextInput {
                id: nameField
                anchors.fill: parent
                anchors.margins: 10
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: 14
                color: "#1f2937"
                clip: true

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "e.g. Website Redesign"
                    color: "#adb5bd"
                    font.pixelSize: 14
                    visible: !nameField.text && !nameField.activeFocus
                }

                Keys.onReturnPressed: billingCodeField.forceActiveFocus()
            }
        }

        // ── Billing code ──────────────────────────────────────────
        Label {
            text: "Billing Code"
            font.pixelSize: 12
            color: "#6b7280"
            Layout.bottomMargin: 4
        }
        Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: 4
            color: "#ffffff"
            border.color: billingCodeField.activeFocus ? "#2563eb" : "#e5e7eb"
            border.width: 1
            Layout.bottomMargin: 18

            TextInput {
                id: billingCodeField
                anchors.fill: parent
                anchors.margins: 10
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: 14
                color: "#1f2937"
                clip: true

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Optional"
                    color: "#adb5bd"
                    font.pixelSize: 14
                    visible: !billingCodeField.text && !billingCodeField.activeFocus
                }

                Keys.onReturnPressed: {
                    if (nameField.text.trim() !== "") createProject()
                }
            }
        }

        // ── Billable toggle ───────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 22
            spacing: 0

            ColumnLayout {
                spacing: 2
                Label {
                    text: "Billable"
                    font.pixelSize: 14
                    color: "#1f2937"
                }
                Label {
                    text: projectDialog.billable ? "Time will be billed to client" : "Internal / non-billable"
                    font.pixelSize: 11
                    color: "#9ca3af"
                }
            }

            Item { Layout.fillWidth: true }

            // Toggle switch
            Rectangle {
                width: 48; height: 26; radius: 13
                color: projectDialog.billable ? "#2563eb" : "#d1d5db"

                Behavior on color { ColorAnimation { duration: 120 } }

                Rectangle {
                    id: thumb
                    width: 20; height: 20; radius: 10
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                    x: projectDialog.billable ? parent.width - width - 3 : 3
                    Behavior on x { NumberAnimation { duration: 120 } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: projectDialog.billable = !projectDialog.billable
                }
            }
        }

        // ── Buttons ───────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                height: 40; radius: 4
                color: cancelMa.containsMouse ? "#f3f4f6" : "#ffffff"
                border.color: "#e5e7eb"; border.width: 1

                Label {
                    anchors.centerIn: parent
                    text: "Cancel"
                    font.pixelSize: 14
                    color: "#6b7280"
                }
                MouseArea {
                    id: cancelMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: projectDialog.close()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 40; radius: 4
                color: {
                    if (!nameValid) return "#9ca3af"
                    return createMa.containsMouse ? "#374151" : "#1f2937"
                }

                property bool nameValid: nameField.text.trim() !== ""

                Label {
                    anchors.centerIn: parent
                    text: "Create Project"
                    font.pixelSize: 14
                    color: "white"
                }
                MouseArea {
                    id: createMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.nameValid ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (parent.nameValid) createProject()
                }
            }
        }
    }

    function createProject() {
        backend.addProject(
            nameField.text.trim(),
            billingCodeField.text.trim(),
            projectDialog.billable
        )
        projectDialog.close()
    }
}
