{...}: {
  wayland.windowManager.hyprland.extraConfig = ''
    exec-once = wayvnc 0.0.0.0
  '';
}
