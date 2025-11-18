{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.programs.proton;
in
{
  options.programs.proton = {
    enable = mkEnableOption "Proton applications suite";

    vpn = {
      enable = mkOption {
        type = types.bool;
        default = false; # Temporarily disabled due to proton-core test failures
        description = "Enable ProtonVPN applications (GUI and CLI)";
      };
    };

    pass = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Proton Pass password manager";
      };
    };

    mail = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable ProtonMail desktop application";
      };
    };

    authenticator = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Proton Authenticator";
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs;
      # VPN packages
      (optionals cfg.vpn.enable [
        protonvpn-gui
        # NOTE: protonvpn-cli was removed upstream, use GUI instead
      ])
      # Password manager
      ++ (optionals cfg.pass.enable [
        proton-pass
      ])
      # Email client
      ++ (optionals cfg.mail.enable [
        protonmail-desktop
      ])
      # Authenticator
      ++ (optionals cfg.authenticator.enable [
        proton-authenticator
      ]);

    # Desktop entries and application settings
    xdg.desktopEntries = mkIf cfg.enable {
      # ProtonVPN GUI desktop entry optimization
      protonvpn = mkIf cfg.vpn.enable {
        name = "ProtonVPN";
        comment = "Secure VPN by Proton";
        exec = "protonvpn-app";
        icon = "protonvpn";
        categories = [ "Network" "Security" ];
        terminal = false;
        type = "Application";
      };

      # Proton Pass desktop entry optimization
      proton-pass = mkIf cfg.pass.enable {
        name = "Proton Pass";
        comment = "Secure password manager by Proton";
        exec = "proton-pass";
        icon = "proton-pass";
        categories = [ "Utility" "Security" ];
        terminal = false;
        type = "Application";
      };

      # ProtonMail desktop entry optimization
      protonmail = mkIf cfg.mail.enable {
        name = "ProtonMail";
        comment = "Secure email by Proton";
        exec = "protonmail-desktop";
        icon = "protonmail";
        categories = [ "Network" "Email" "Office" ];
        terminal = false;
        type = "Application";
      };
    };

    # NOTE: Shell aliases for CLI tools disabled - protonvpn-cli was removed upstream
    # Use the ProtonVPN GUI application instead
    # programs.bash.shellAliases = mkIf cfg.vpn.enable {
    #   pvpn = "protonvpn-cli";
    #   pvpn-connect = "protonvpn-cli connect";
    #   pvpn-disconnect = "protonvpn-cli disconnect";
    #   pvpn-status = "protonvpn-cli status";
    # };

    # programs.zsh.shellAliases = mkIf cfg.vpn.enable {
    #   pvpn = "protonvpn-cli";
    #   pvpn-connect = "protonvpn-cli connect";
    #   pvpn-disconnect = "protonvpn-cli disconnect";
    #   pvpn-status = "protonvpn-cli status";
    # };
  };
}
