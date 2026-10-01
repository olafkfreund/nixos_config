{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.programs.obs;

  # OBS 32 deprecated obs_properties_add_button; the C plugins build with
  # -Werror, so the deprecation is fatal. Downgrade that one warning class for
  # every plugin until upstream migrates the API. Applied list-wide rather than
  # per-plugin — the same break hits any plugin using the old properties API.
  # GCC 16/glibc C23 makes strrchr(const char *) return const char *, which
  # trips -Werror=discarded-qualifiers (obs-shaderfilter 2.6.0).
  unWerror = p: p.overrideAttrs (prev: {
    env.NIX_CFLAGS_COMPILE = ((prev.env or { }).NIX_CFLAGS_COMPILE or "") + " -Wno-error=deprecated-declarations -Wno-error=discarded-qualifiers";
  });
in
{
  options.programs.obs = {
    enable = mkEnableOption "OBS Studio for screen recording and streaming";
  };

  config = mkIf cfg.enable {
    programs.obs-studio = {
      enable = true;
      plugins = map unWerror (with pkgs.obs-studio-plugins; [
        wlrobs # Wayland window capture
        obs-backgroundremoval # Virtual background effects
        obs-pipewire-audio-capture # Audio capture for Pipewire
        droidcam-obs # Re-enabled: Compilation error fixed in nixpkgs (issue #29 closed)
        input-overlay # Show keyboard/mouse inputs
        obs-source-record # Record individual sources
        obs-livesplit-one # Speedrunning timer integration
        looking-glass-obs # Low-latency VM window capture
        obs-vintage-filter # Vintage video effects
        obs-command-source # Run shell commands from OBS
        obs-source-switcher # Automatic source switching
        obs-move-transition # Smooth transitions between scenes
        obs-vkcapture # Vulkan/OpenGL game capture
        obs-gstreamer # GStreamer integration
        obs-vaapi # Hardware acceleration support
        obs-shaderfilter # Custom shader effects
        obs-gradient-source # Gradient backgrounds
      ]);
    };
  };
}
