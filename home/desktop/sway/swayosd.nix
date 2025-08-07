{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.desktop.swayosd;
in {
  options.desktop.swayosd = {
    enable = mkEnableOption {
      default = false;
      description = "swayosd";
    };
  };
  config = mkIf cfg.enable {
    services.swayosd = {
      enable = true;
    };
    wayland.windowManager.sway = {
      extraConfig = ''
        # Sink volume raise optionally with --device
        bindsym XF86AudioRaiseVolume exec swayosd-client --output-volume raise
        # Sink volume lower optionally with --device
        bindsym XF86AudioLowerVolume exec  swayosd-client --output-volume lower --device alsa_output.pci-0000_11_00.4.analog-stereo.monitor
        # Sink volume toggle mute
        bindsym XF86AudioMute exec swayosd-client --output-volume mute-toggle
        # Source volume toggle mute
        bindsym XF86AudioMicMute exec swayosd-client --input-volume mute-toggle

        # Volume raise with custom value
        bindsym XF86AudioRaiseVolume exec swayosd-client --output-volume 15
        # Volume lower with custom value
        bindsym XF86AudioLowerVolume exec swayosd-client --output-volume -15

        # Volume raise with max value
        bindsym XF86AudioRaiseVolume exec swayosd-client --output-volume raise --max-volume 120
        # Volume lower with max value
        bindsym XF86AudioLowerVolume exec swayosd-client --output-volume lower --max-volume 120

        # Sink volume raise with custom value optionally with --device
        bindsym XF86AudioRaiseVolume exec  swayosd-client --output-volume +10 --device alsa_output.pci-0000_11_00.4.analog-stereo.monitor
        # Sink volume lower with custom value optionally with --device
        bindsym XF86AudioLowerVolume exec  swayosd-client --output-volume -10 --device alsa_output.pci-0000_11_00.4.analog-stereo.monitor

        # Capslock (If you don't want to use the backend)
        bindsym --release Caps_Lock exec swayosd-client --caps-lock
        # Capslock but specific LED name (/sys/class/leds/)
        bindsym --release Caps_Lock exec swayosd-client --caps-lock-led input19::capslock

        # Brightness raise
        bindsym XF86MonBrightnessUp exec swayosd-client --brightness raise
        # Brightness lower
        bindsym XF86MonBrightnessDown exec swayosd-client --brightness lower

        # Brightness raise with custom value('+' sign needed)
        bindsym XF86MonBrightnessUp  exec swayosd-client --brightness +10
        # Brightness lower with custom value('-' sign needed)
        bindsym XF86MonBrightnessDown exec swayosd-client --brightness -10
      '';
    };
  };
}
