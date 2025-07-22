{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.features.email;
in {
  imports = [
    ./neomutt
  ];

  options.features.email = {
    enable = mkEnableOption "Email system with NeoMutt and Gmail integration";
    
    accounts = {
      primary = mkOption {
        type = types.str;
        default = "olaf@freundcloud.com";
        description = "Primary email account";
      };
      
      secondary = mkOption {
        type = types.str;
        default = "olaf.loken@gmail.com"; 
        description = "Secondary email account";
      };
    };
    
    neomutt = {
      enable = mkEnableOption "NeoMutt email client" // { default = true; };
    };
    
    ai = {
      enable = mkEnableOption "AI-powered email processing";
      provider = mkOption {
        type = types.enum [ "openai" "anthropic" "gemini" ];
        default = "openai";
        description = "AI provider for email processing";
      };
    };
    
    notifications = {
      enable = mkEnableOption "Email notifications via SwayNC";
      highPriorityOnly = mkOption {
        type = types.bool;
        default = true;
        description = "Only show notifications for high-priority emails";
      };
    };
  };

  config = mkIf cfg.enable {
    # Email system will be configured through the neomutt module
    assertions = [
      {
        assertion = cfg.neomutt.enable -> (cfg.accounts.primary != "" && cfg.accounts.secondary != "");
        message = "Email accounts must be configured when NeoMutt is enabled";
      }
    ];
    
    # Add email packages to system
    environment.systemPackages = with pkgs; mkIf cfg.neomutt.enable [
      neomutt
      isync        # For mbsync email synchronization
      msmtp        # For SMTP email sending
      w3m          # For HTML email rendering
      notmuch      # For email indexing and search
    ];
  };
}