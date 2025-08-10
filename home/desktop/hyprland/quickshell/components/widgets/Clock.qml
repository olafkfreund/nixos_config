// Clock Widget
// Displays current time with customizable format
import QtQuick 2.15

Text {
    id: clock

    property var theme
    property string format: "hh:mm:ss"

    text: Qt.formatDateTime(new Date(), format)
    color: theme.foreground || "#ebdbb2"
    font.pixelSize: 12
    font.weight: Font.Medium

    // Update every second
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            clock.text = Qt.formatDateTime(new Date(), clock.format)
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        onClicked: {
            // Toggle between time formats on click
            if (clock.format === "hh:mm:ss") {
                clock.format = "dddd, MMMM d"
            } else {
                clock.format = "hh:mm:ss"
            }
        }

        onEntered: {
            clock.color = theme.accent || "#d79921"
        }

        onExited: {
            clock.color = theme.foreground || "#ebdbb2"
        }
    }

    // Smooth color transitions
    Behavior on color {
        ColorAnimation { duration: 150 }
    }
}
