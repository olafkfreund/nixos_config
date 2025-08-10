// Audio Indicator Widget
// Shows audio volume and mute status
import QtQuick 2.15
import Quickshell.Services.Pipewire 2.0

Rectangle {
    id: audioIndicator

    property var theme
    width: 32
    height: 18
    radius: 3
    color: "transparent"

    border.color: {
        if (Pipewire.defaultAudioSink?.muted) {
            return theme.urgent || "#cc241d"
        } else {
            return theme.foreground || "#ebdbb2"
        }
    }
    border.width: 1

    // Volume fill indicator
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 2

        width: {
            if (!Pipewire.defaultAudioSink) return 0
            return (parent.width - 4) * (Pipewire.defaultAudioSink.volume || 0)
        }

        radius: 1
        color: {
            if (Pipewire.defaultAudioSink?.muted) {
                return theme.urgent || "#cc241d"
            } else {
                var volume = Pipewire.defaultAudioSink?.volume || 0
                if (volume > 0.8) return theme.warning || "#d65d0e"
                return theme.success || "#98971a"
            }
        }

        // Smooth volume animation
        Behavior on width {
            NumberAnimation { duration: 200; easing.type: Easing.OutQuart }
        }

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    // Volume percentage or mute indicator
    Text {
        anchors.centerIn: parent
        text: {
            if (!Pipewire.defaultAudioSink) return "N/A"
            if (Pipewire.defaultAudioSink.muted) return "🔇"
            return Math.round((Pipewire.defaultAudioSink.volume || 0) * 100) + "%"
        }
        color: theme.background || "#1d2021"
        font.pixelSize: 8
        font.weight: Font.Bold
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: function(mouse) {
            if (!Pipewire.defaultAudioSink) return

            if (mouse.button === Qt.LeftButton) {
                // Toggle mute
                Pipewire.defaultAudioSink.muted = !Pipewire.defaultAudioSink.muted
            } else if (mouse.button === Qt.RightButton) {
                // Could open volume control or mixer
                console.log("Audio right-clicked - implement volume control")
            }
        }

        onWheel: function(wheel) {
            if (!Pipewire.defaultAudioSink) return

            // Scroll to adjust volume
            var delta = wheel.angleDelta.y / 120 * 0.05  // 5% per scroll
            var newVolume = Math.max(0, Math.min(1, Pipewire.defaultAudioSink.volume + delta))
            Pipewire.defaultAudioSink.volume = newVolume
        }

        hoverEnabled: true
        onEntered: {
            audioIndicator.scale = 1.05
        }

        onExited: {
            audioIndicator.scale = 1.0
        }
    }

    // Hover animation
    Behavior on scale {
        NumberAnimation { duration: 150; easing.type: Easing.OutQuart }
    }

    // Border color animation
    Behavior on border.color {
        ColorAnimation { duration: 200 }
    }
}
