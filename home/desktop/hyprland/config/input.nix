{...}: {
  wayland.windowManager.hyprland.extraConfig = ''
    input {
      kb_layout=gb
      kb_variant=
      kb_model=
      kb_options=
      kb_rules=
      follow_mouse=1
      touchpad {
        natural_scroll=no
      }
    }
  '';
}
