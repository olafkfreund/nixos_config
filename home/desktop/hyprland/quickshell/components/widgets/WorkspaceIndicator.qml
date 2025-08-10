// Workspace Indicator Widget
// Shows current and available workspaces
import QtQuick 2.15
import QtQuick.Controls 2.15
import Quickshell.Hyprland 2.0

Row {
    id: workspaceIndicator

    property var theme
    spacing: 4

    // Workspace repeater
    Repeater {
        model: Hyprland.workspaces

        delegate: Rectangle {
            width: 24
            height: 18
            radius: 4

            property bool isActive: modelData.id === Hyprland.focusedWorkspace?.id
            property bool hasWindows: modelData.windows.length > 0

            color: {
                if (isActive) {
                    return Qt.rgba(
                        parseInt(theme.accent?.substring(1, 3) || "d7", 16) / 255,
                        parseInt(theme.accent?.substring(3, 5) || "99", 16) / 255,
                        parseInt(theme.accent?.substring(5, 7) || "21", 16) / 255,
                        1.0
                    )
                } else if (hasWindows) {
                    return Qt.rgba(
                        parseInt(theme.foreground?.substring(1, 3) || "eb", 16) / 255,
                        parseInt(theme.foreground?.substring(3, 5) || "db", 16) / 255,
                        parseInt(theme.foreground?.substring(5, 7) || "b2", 16) / 255,
                        0.4
                    )
                } else {
                    return Qt.rgba(
                        parseInt(theme.foreground?.substring(1, 3) || "eb", 16) / 255,
                        parseInt(theme.foreground?.substring(3, 5) || "db", 16) / 255,
                        parseInt(theme.foreground?.substring(5, 7) || "b2", 16) / 255,
                        0.1
                    )
                }
            }

            border.color: isActive ? "transparent" : Qt.rgba(
                parseInt(theme.foreground?.substring(1, 3) || "eb", 16) / 255,
                parseInt(theme.foreground?.substring(3, 5) || "db", 16) / 255,
                parseInt(theme.foreground?.substring(5, 7) || "b2", 16) / 255,
                0.2
            )
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: modelData.id
                color: isActive ?
                    theme.background || "#1d2021" :
                    theme.foreground || "#ebdbb2"
                font.pixelSize: 10
                font.weight: Font.Medium
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Hyprland.dispatch("workspace " + modelData.id)

                hoverEnabled: true
                onEntered: parent.scale = 1.1
                onExited: parent.scale = 1.0
            }

            // Smooth scaling animation
            Behavior on scale {
                NumberAnimation { duration: 150; easing.type: Easing.OutQuart }
            }

            // Smooth color transitions
            Behavior on color {
                ColorAnimation { duration: 200 }
            }
        }
    }
}
