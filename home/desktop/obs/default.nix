{ pkgs
, ...
}: {
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-backgroundremoval
      obs-pipewire-audio-capture
      droidcam-obs
      input-overlay
      advanced-scene-switcher
      obs-source-switcher
      obs-move-transition
    ];
  };
}
