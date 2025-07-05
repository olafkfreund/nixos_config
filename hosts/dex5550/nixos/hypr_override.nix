{...}: {
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      "wayvnc 0.0.0.0 5900"
    ];
  };
}
