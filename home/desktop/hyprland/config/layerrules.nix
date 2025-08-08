_: {
  wayland.windowManager.hyprland.extraConfig = ''
    # =============================================================================
    # LAYER RULES
    # =============================================================================

    # Foot terminal layer animation rule - slide from top
    # layerrule = animation slide, ^(foot)$
    layerrule = animation slide down,focus,^(foot)$
    layerrule = animation slide up,blur,^(foot)$

    # Add any other layerrules below
  '';
}
