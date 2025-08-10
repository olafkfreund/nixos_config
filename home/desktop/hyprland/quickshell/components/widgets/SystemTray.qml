// System Tray Widget
// Basic system tray implementation
import QtQuick 2.15
import Quickshell.Services.SystemTray 2.0

Row {
    id: systemTray

    property var theme
    spacing: 4

    // System tray items repeater
    Repeater {
        model: SystemTray.items

        delegate: Rectangle {
            width: 20
            height: 20
            radius: 3
            color: "transparent"

            border.color: Qt.rgba(
                parseInt(theme.foreground?.substring(1, 3) || "eb", 16) / 255,
                parseInt(theme.foreground?.substring(3, 5) || "db", 16) / 255,
                parseInt(theme.foreground?.substring(5, 7) || "b2", 16) / 255,
                0.1
            )
            border.width: 1

            // System tray icon
            Image {
                anchors.centerIn: parent
                width: 14
                height: 14
                source: modelData.icon || ""
                fillMode: Image.PreserveAspectFit
                smooth: true

                // Fallback to text if no icon
                Text {
                    visible: parent.source == ""
                    anchors.centerIn: parent
                    text: modelData.title?.substring(0, 1) || "?"
                    color: theme.foreground || "#ebdbb2"
                    font.pixelSize: 8
                    font.weight: Font.Bold
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: function(mouse) {
                    if (mouse.button === Qt.LeftButton) {
                        modelData.activate()
                    } else if (mouse.button === Qt.RightButton) {
                        modelData.contextMenu()
                    }
                }

                hoverEnabled: true
                onEntered: {
                    parent.color = Qt.rgba(
                        parseInt(theme.accent?.substring(1, 3) || "d7", 16) / 255,
                        parseInt(theme.accent?.substring(3, 5) || "99", 16) / 255,
                        parseInt(theme.accent?.substring(5, 7) || "21", 16) / 255,
                        0.2
                    )
                }

                onExited: {
                    parent.color = "transparent"
                }
            }

            // Hover animation
            Behavior on color {
                ColorAnimation { duration: 150 }
            }
        }
    }
}
