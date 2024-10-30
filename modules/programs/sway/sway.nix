{
  pkgs,
  config,
  lib,
  ...
}: {
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true; # so that gtk works properly
    extraPackages = with pkgs; [
      swaylock
      swayidle
      swaycons
      wl-clipboard
      wf-recorder
      wlr-which-key
      wlr-randr
      grim
      slurp
      foot
      dmenu # Dmenu is the default in the config but i recommend wofi since its wayl
    ];
    extraSessionCommands = ''
      export SDL_VIDEODRIVER=wayland
      export QT_QPA_PLATFORM=wayland
      export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
      export _JAVA_AWT_WM_NONREPARENTING=1
      export MOZ_ENABLE_WAYLAND=1
      # export WLR_BACKENDS="headless,libinput"
      # export WLR_LIBINPUT_NO_DEVICES="1"
    '';
  };
  programs.light.enable = true;
  # Gnome keyring
  services.gnome.gnome-keyring.enable = true;
}
