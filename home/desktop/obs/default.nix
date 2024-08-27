{pkgs, ...}: {
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
      obs-vkcapture
      obs-gstreamer
      obs-vaapi
      obs-source-record
      obs-shaderfilter
      obs-gradient-source
      obs-ndi
    ];
  };
}
