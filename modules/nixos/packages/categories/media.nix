# Media Packages
# Media processing, streaming, and entertainment tools
# Compliant with NIXOS-ANTI-PATTERNS.md
{ config, lib, pkgs, ... }:
let
  cfg = config.packages.media;
  # Import existing media package sets
  packageSets = import ../../packages/sets.nix { inherit pkgs lib; };
in
{
  options.packages.media = {
    enable = lib.mkEnableOption "Media packages";

    server = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable media server tools (headless-compatible)";
    };

    processing = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable media processing tools (headless-compatible)";
    };

    gui = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable GUI media applications (requires desktop)";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs;
      # Media server tools (headless-compatible)
      lib.optionals cfg.server [
        ffmpeg
        mediainfo
        youtube-dl
        yt-dlp
        rsync
        rclone
      ]

      # Media processing tools (headless-compatible)
      ++ lib.optionals cfg.processing [
        ffmpeg-full
        imagemagick
        sox
        lame
        flac
        opus-tools
      ]

      # GUI media applications (only if desktop enabled)
      ++ lib.optionals (cfg.gui && (config.packages.desktop.enable or false))
        packageSets.media;
  };
}
