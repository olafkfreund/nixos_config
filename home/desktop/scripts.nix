{
  pkgs,
  config,
  libs,
  inputs,
  ...
}: let
  wallpaper_path = "$HOME/Pictures/wallpapers/gruvbox/";
in {
  home = {
    packages = with pkgs; [
      (pkgs.writeShellScriptBin "gamemode" ''
        HYPRGAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==2{print $2}')
        if [ "$HYPRGAMEMODE" = 1 ] ; then
            hyprctl --batch "\
                keyword animations:enabled 0;\
                keyword decoration:drop_shadow 0;\
                keyword decoration:blur:enabled 0;\
                keyword general:gaps_in 0;\
                keyword general:gaps_out 0;\
                keyword general:border_size 1;\
                keyword decoration:rounding 0"
            exit
        fi
        hyprctl reload
      '')

      (pkgs.writeShellScriptBin "rofi-powermenu" ''
        rofi_command="rofi -theme $HOME/.config/rofi/rofi-powermenu-gruvbox-config.rasi"

        power_off="⏻ "
        reboot=" "
        lock="󰌾 "
        suspend="󰤄 "
        log_out=" "
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
