// QuickShell Main Entry Point
// Top-level shell configuration
import QtQuick 2.15
import Quickshell 2.0
import Quickshell.Wayland 2.0

ShellRoot {
    id: shell

    property var config: Quickshell.config
    property var theme: config.colors || {}

    // Create bar for each monitor
    Repeater {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: bar
            screen: modelData

            // Position at top of screen (above waybar)
            anchors {
                left: true
                right: true
                top: true
            }

            height: config.bar.height || 32

            // Layer shell configuration for top position
            layer: PanelWindow.LayerTop
            exclusiveZone: height

            // Styling
            color: Qt.rgba(
                parseInt(theme.background?.substring(1, 3) || "1d", 16) / 255,
                parseInt(theme.background?.substring(3, 5) || "20", 16) / 255,
                parseInt(theme.background?.substring(5, 7) || "21", 16) / 255,
                config.bar.transparent ? 0.9 : 1.0
            )

            // Load the main bar component
            Loader {
                anchors.fill: parent
                source: "bar.qml"
                onLoaded: {
                    item.config = shell.config
                    item.theme = shell.theme
                }
            }
        }
    }
}
