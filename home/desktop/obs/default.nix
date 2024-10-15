{
  inputs,
  config,
  lib,
  pkgs,
  pkgs-stable,
  ...
}: 
with lib; let
  cfg = config.programs.obs;
in {
  options.programs.obs = {
    enable = mkEnableOption {
      default = false;
      description = "obs-studio";
    };
  };
  config = mkIf cfg.enable {
    programs.obs-studio = {
      enable = true;
      plugins = with pkgs-stable.obs-studio-plugins; [
        wlrobs
        obs-backgroundremoval
        obs-pipewire-audio-capture
        droidcam-obs
        input-overlay
        # advanced-scene-switcher
        obs-source-record
        obs-livesplit-one
        looking-glass-obs
        obs-vintage-filter
        obs-command-source
        obs-source-switcher
        obs-move-transition
        obs-vkcapture
        obs-gstreamer
        obs-vaapi
        obs-source-record
        obs-shaderfilter
        obs-gradient-source
        obs-ndi
      ];
    };
  };
}
