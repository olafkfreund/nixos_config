{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.features.programs.yt-x;
in
{
  options.features.programs.yt-x = {
    enable = mkEnableOption "yt-x terminal YouTube browser";
  };

  config = mkIf cfg.enable {
    # Install yt-x dependencies (yt-x itself will be added directly in host config)
    environment.systemPackages = with pkgs; [
      yt-dlp
      jq
      fzf
      mpv
      ffmpeg
      gum # For enhanced UI
    ];
  };
}
