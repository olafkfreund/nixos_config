# Quick NixOS Module Snippets

## Basic Module Header
```nix
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.modules.CATEGORY.MODULE_NAME;
in {
  options.modules.CATEGORY.MODULE_NAME = {
    enable = mkEnableOption "DESCRIPTION";
  };
  
  config = mkIf cfg.enable {
    # Configuration here
  };
}
```

## Common Option Types

### String Option
```nix
optionName = mkOption {
  type = types.str;
  default = "default-value";
  description = "Description of option";
  example = "example-value";
};
```

### Boolean Option
```nix
enableFeature = mkOption {
  type = types.bool;
  default = false;
  description = "Enable optional feature";
};
```

### Package Option
```nix
package = mkOption {
  type = types.package;
  default = pkgs.package-name;
  description = "Package to use";
};
```

### List of Packages
```nix
extraPackages = mkOption {
  type = types.listOf types.package;
  default = [];
  description = "Additional packages";
  example = literalExpression "[ pkgs.pkg1 pkgs.pkg2 ]";
};
```

### Port Option
```nix
port = mkOption {
  type = types.port;
  default = 8080;
  description = "Port to listen on";
};
```

### Enum Option
```nix
logLevel = mkOption {
  type = types.enum [ "debug" "info" "warn" "error" ];
  default = "info";
  description = "Log level";
};
```

### Attribute Set
```nix
settings = mkOption {
  type = types.attrsOf types.str;
  default = {};
  description = "Configuration settings";
  example = literalExpression ''
    {
      key1 = "value1";
      key2 = "value2";
    }
  '';
};
```

## Service Configuration

### Basic Service
```nix
systemd.services.service-name = {
  description = "Service Description";
  after = [ "network.target" ];
  wantedBy = [ "multi-user.target" ];
  
  serviceConfig = {
    Type = "simple";
    User = "service-user";
    Group = "service-group";
    ExecStart = "${cfg.package}/bin/command";
    Restart = "always";
    RestartSec = "10s";
  };
};
```

### Hardened Service
```nix
systemd.services.service-name = {
  description = "Hardened Service";
  after = [ "network.target" ];
  wantedBy = [ "multi-user.target" ];
  
  serviceConfig = {
    Type = "simple";
    User = "service-user";
    Group = "service-group";
    ExecStart = "${cfg.package}/bin/command";
    
    # Restart
    Restart = "always";
    RestartSec = "10s";
    
    # Security
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectHome = true;
    ProtectSystem = "strict";
    ReadWritePaths = [ "/var/lib/service" ];
  };
};
```

## User Management

### System User
```nix
users.users.service-user = {
  isSystemUser = true;
  group = "service-group";
  description = "Service user";
  home = "/var/lib/service";
  createHome = true;
};

users.groups.service-group = {};
```

### Normal User
```nix
users.users.username = {
  isNormalUser = true;
  description = "User Name";
  extraGroups = [ "wheel" "networkmanager" ];
  shell = pkgs.zsh;
  hashedPasswordFile = "/run/agenix/user-password-username";
};
```

## Directory Setup
```nix
systemd.tmpfiles.rules = [
  "d /var/lib/service 0755 service-user service-group -"
  "d /var/log/service 0755 service-user service-group -"
  "f /etc/service/config.conf 0644 root root -"
];
```

## Conditional Configuration

### Simple Conditional
```nix
config = mkIf cfg.enable {
  environment.systemPackages = [ cfg.package ];
};
```

### Multiple Conditions
```nix
programs.example = mkIf (cfg.enable && cfg.advanced) {
  enable = true;
  settings = cfg.settings;
};
```

### Optional Lists
```nix
environment.systemPackages = with pkgs; [
  base-package
] 
++ optional cfg.enableFeature1 feature1-package
++ optionals cfg.enableFeatures [ pkg1 pkg2 pkg3 ];
```

## Validation

### Assertions
```nix
assertions = [
  {
    assertion = cfg.port > 1024;
    message = "Port must be greater than 1024";
  }
  {
    assertion = cfg.enable -> config.networking.enable;
    message = "Service requires networking";
  }
];
```

### Warnings
```nix
warnings = [
  (mkIf (cfg.enable && !cfg.secure) ''
    Service running in insecure mode
  '')
];
```

## Configuration Files

### JSON Config
```nix
configFile = pkgs.writeText "config.json" (builtins.toJSON {
  setting1 = cfg.setting1;
  setting2 = cfg.setting2;
});
```

### INI Config
```nix
configFile = pkgs.writeText "config.ini" ''
  [section]
  key1 = ${cfg.value1}
  key2 = ${cfg.value2}
  
  ${concatStringsSep "\n" (mapAttrsToList (k: v: "${k} = ${v}") cfg.settings)}
'';
```

## Networking

### Firewall Ports
```nix
networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];
```

### Multiple Ports
```nix
networking.firewall = {
  allowedTCPPorts = [ 80 443 ];
  allowedUDPPorts = [ 53 ];
};
```

## Environment Variables
```nix
environment.variables = {
  SERVICE_HOME = "/etc/service";
  SERVICE_CONFIG = cfg.configFile;
};
```

## Shell Integration
```nix
environment.shellAliases = mkIf cfg.enableShellIntegration {
  service-start = "systemctl start service-name";
  service-stop = "systemctl stop service-name";
  service-status = "systemctl status service-name";
};
```

## Development Features

### LSP Support
```nix
environment.systemPackages = optionals cfg.enableLSP [
  language-server-package
  lsp-tools
];
```

### Editor Integration
```nix
programs.vscode = mkIf cfg.enableEditorIntegration {
  extensions = with pkgs.vscode-extensions; [
    relevant-extension
  ];
};
```