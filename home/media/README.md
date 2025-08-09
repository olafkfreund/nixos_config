# Media Configuration

This directory contains configurations for media playback and management tools.

## Components

- `music.nix` - Music playback configuration and tools
- `rnoise.nix` - Noise reduction tools
- `spice_themes.nix` - Spicetify themes for Spotify
- `mpd/` - Music Player Daemon configuration
- `mpv/` - MPV media player configuration

## Features

The media configurations provide:

- Music playback through MPD and clients
- Integration with Spotify through Spicetify
- Audio tweaking and noise reduction
- Video playback with MPV
- Theme customizations for media players

## Usage

These configurations are imported in the Home Manager configuration to provide a consistent media playback experience across systems. They integrate with the system's audio stack (PipeWire/PulseAudio) and can be controlled through various interfaces.
