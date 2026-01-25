{ pkgs, ... }: {
  home = {
    packages = with pkgs; [
      # Desktop scripts removed:
      # - gamemode script (Hyprland-specific, removed)
      # - rofi-powermenu (Rofi removed from configuration)
    ];
  };
}
