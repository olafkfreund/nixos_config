// Network Indicator Widget
// Shows network connectivity status
import QtQuick 2.15
import Quickshell.Services.Network 2.0

Rectangle {
    id: networkIndicator

    property var theme
    width: 24
    height: 18
    radius: 3
    color: "transparent"

    border.color: {
        if (Network.connectivity === Network.ConnectivityFull) {
            return theme.success || "#98971a"
        } else if (Network.connectivity === Network.ConnectivityLimited) {
            return theme.warning || "#d65d0e"
        } else {
            return theme.urgent || "#cc241d"
        }
    }
    border.width: 1

    // Network icon/indicator
    Text {
        anchors.centerIn: parent
        text: {
            if (Network.primaryConnection?.type === Network.ConnectionWifi) {
                return "📶"  // WiFi icon
            } else if (Network.primaryConnection?.type === Network.ConnectionEthernet) {
                return "🔗"  // Ethernet icon
            } else if (Network.connectivity === Network.ConnectivityNone) {
                return "❌"  // No connection
            } else {
                return "❓"  // Unknown
            }
        }
        font.pixelSize: 10
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        onClicked: {
            // Could open network manager or show connection details
            console.log("Network clicked - implement action")
        }

        onEntered: {
            networkIndicator.color = Qt.rgba(
                parseInt(theme.accent?.substring(1, 3) || "d7", 16) / 255,
                parseInt(theme.accent?.substring(3, 5) || "99", 16) / 255,
                parseInt(theme.accent?.substring(5, 7) || "21", 16) / 255,
                0.2
            )
        }

        onExited: {
            networkIndicator.color = "transparent"
        }
    }

    // Connection status tooltip (simplified)
    Rectangle {
        id: tooltip
        visible: false
        width: tooltipText.width + 12
        height: tooltipText.height + 8
        color: theme.background || "#1d2021"
        border.color: theme.foreground || "#ebdbb2"
        border.width: 1
        radius: 4

        anchors.bottom: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 5

        Text {
            id: tooltipText
            anchors.centerIn: parent
            text: {
                if (Network.primaryConnection) {
                    return Network.primaryConnection.id + "\n" +
                           (Network.primaryConnection.type === Network.ConnectionWifi ?
                            "WiFi" : "Ethernet")
                } else {
                    return "No Connection"
                }
            }
            color: theme.foreground || "#ebdbb2"
            font.pixelSize: 9
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // Show tooltip on hover
    Timer {
        id: tooltipTimer
        interval: 1000
        onTriggered: tooltip.visible = true
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        onEntered: {
            tooltipTimer.start()
        }

        onExited: {
            tooltipTimer.stop()
            tooltip.visible = false
        }
    }

    // Smooth animations
    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    Behavior on border.color {
        ColorAnimation { duration: 200 }
    }
}
