{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.scrcpyWifi;
  # Script to automate adb Wi-Fi connection and launch scrcpy
  scrcpyWifiScript = pkgs.writeShellScriptBin "scrcpy-wifi" ''
    set -e

    if [ -z "$1" ]; then
      echo "Usage: scrcpy-wifi <device-ip> [port]"
      exit 1
    fi

    DEVICE_IP="$1"
    PORT="''${2:-5555}"

    # Switch device to TCP/IP mode (ignore errors if already in this mode)
    adb tcpip "$PORT" || true

    # Connect over Wi-Fi
    adb connect "$DEVICE_IP:$PORT"

    # Launch scrcpy
    scrcpy
  '';
in
{
  options.scrcpyWifi = {
    enable = mkEnableOption "Enable scrcpy Wi-Fi automation module";

    defaultPort = mkOption {
      type = types.int;
      default = 5555;
      description = "Default TCP/IP port for adb Wi-Fi connection";
      example = 5555;
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      scrcpy
      android-tools
      scrcpyWifiScript
    ];

    # Android device access is now handled by built-in systemd uaccess rules
    # No need for separate android-udev-rules package
  };
}
