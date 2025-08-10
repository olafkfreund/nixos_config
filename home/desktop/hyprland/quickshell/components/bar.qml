// QuickShell Bar Component
// Main bar layout and widget container
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import "widgets" as Widgets

Rectangle {
    id: bar

    property var config
    property var theme

    color: "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 12

        // Left section - Workspaces
        Item {
            Layout.alignment: Qt.AlignLeft
            Layout.preferredWidth: childrenRect.width
            height: parent.height

            Widgets.WorkspaceIndicator {
                anchors.centerIn: parent
                visible: config.widgets.workspaces || false
                theme: bar.theme
            }
        }

        // Center section - Clock
        Item {
            Layout.fillWidth: true
            height: parent.height

            Widgets.Clock {
                anchors.centerIn: parent
                visible: config.widgets.clock || false
                theme: bar.theme
                format: "hh:mm:ss"
            }
        }

        // Right section - System indicators
        Row {
            Layout.alignment: Qt.AlignRight
            spacing: 8
            height: parent.height

            Widgets.AudioIndicator {
                visible: config.widgets.audio || false
                theme: bar.theme
            }

            Widgets.NetworkIndicator {
                visible: config.widgets.network || false
                theme: bar.theme
            }

            Widgets.BatteryIndicator {
                visible: config.widgets.battery || false
                theme: bar.theme
            }

            Widgets.SystemTray {
                visible: config.widgets.systemTray || false
                theme: bar.theme
            }
        }
    }

    // Subtle bottom border
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Qt.rgba(
            parseInt(theme.accent?.substring(1, 3) || "d7", 16) / 255,
            parseInt(theme.accent?.substring(3, 5) || "99", 16) / 255,
            parseInt(theme.accent?.substring(5, 7) || "21", 16) / 255,
            0.3
        )
    }
}
