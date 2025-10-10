{ pkgs, ... }: {
  home = {
    packages = with pkgs; [
      # gamemode script removed - was Hyprland-specific with hyprctl commands
      # Consider implementing desktop-environment-aware version if needed

      (pkgs.writeShellScriptBin "rofi-powermenu" ''
        rofi_command="rofi -theme $HOME/.config/rofi/rofi-powermenu-gruvbox-config.rasi"

        power_off="⏻ "
        reboot=" "
        lock="󰌾 "
        suspend="󰤄 "
        log_out=" "
        host=`hostname`
        uptime=`uptime | awk '{print ($3)}'`

        options="$power_off\n$reboot\n$lock\n$suspend\n$log_out"

        output="$(echo -e "$options" | $rofi_command -dmenu -p $host)"

        case $output in
            $power_off)
              poweroff
              ;;
            $reboot)
              reboot
              ;;
            $lock)
              swaylock&
              ;;
            $suspend)
              swaylock&
              systemctl suspend
              ;;
            $log_out)
              echo logout
              ;;
        esac
      '')
    ];
  };
}
