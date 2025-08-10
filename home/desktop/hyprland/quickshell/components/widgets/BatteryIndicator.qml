// Battery Indicator Widget
// Shows battery status and percentage
import QtQuick 2.15
import Quickshell.Services.UPower 2.0

Rectangle {
    id: batteryIndicator

    property var theme
    width: 40
    height: 18
    radius: 3
    color: "transparent"

    // Only show if battery is available
    visible: UPower.displayDevice?.available || false

    border.color: {
        if (!UPower.displayDevice) return theme.foreground || "#ebdbb2"

        var percentage = UPower.displayDevice.percentage || 0
        if (percentage < 20) return theme.urgent || "#cc241d"
        if (percentage < 40) return theme.warning || "#d65d0e"
        return theme.foreground || "#ebdbb2"
    }
    border.width: 1

    // Battery fill indicator
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 2

        width: {
            if (!UPower.displayDevice) return 0
            return (parent.width - 4) * (UPower.displayDevice.percentage / 100)
        }

        radius: 1
        color: {
            if (!UPower.displayDevice) return "transparent"

            var percentage = UPower.displayDevice.percentage || 0
            if (percentage < 20) return theme.urgent || "#cc241d"
            if (percentage < 40) return theme.warning || "#d65d0e"
            return theme.success || "#98971a"
        }

        // Smooth fill animation
        Behavior on width {
            NumberAnimation { duration: 300; easing.type: Easing.OutQuart }
        }

        Behavior on color {
            ColorAnimation { duration: 200 }
        }
    }

    // Battery percentage text
    Text {
        anchors.centerIn: parent
        text: UPower.displayDevice ? Math.round(UPower.displayDevice.percentage) + "%" : "N/A"
        color: theme.background || "#1d2021"
        font.pixelSize: 8
        font.weight: Font.Bold
    }

    // Charging indicator (small lightning bolt)
    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 1

        visible: UPower.displayDevice?.state === UPower.ChargingState
        text: "⚡"
        color: theme.accent || "#d79921"
        font.pixelSize: 8
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        onEntered: {
            batteryIndicator.scale = 1.05
        }

        onExited: {
            batteryIndicator.scale = 1.0
        }
    }

    // Hover animation
    Behavior on scale {
        NumberAnimation { duration: 150; easing.type: Easing.OutQuart }
    }
}
