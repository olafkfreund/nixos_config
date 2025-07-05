# Configuration validation and testing utilities
{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) mkOption types;
  
  # Validation rules
  validationRules = {
    # Security validation
    security = {
      firewallEnabled = {
        assertion = config.networking.firewall.enable;
        message = "Firewall should be enabled for security";
        severity = "warning";
      };
      
      sshRootLogin = {
        assertion = !config.services.openssh.settings.PermitRootLogin or false;
        message = "SSH root login should be disabled";
        severity = "error";
      };
      
      passwordAuthentication = {
        assertion = !config.services.openssh.settings.PasswordAuthentication or false;
        message = "SSH password authentication should be disabled";
        severity = "warning";
      };
    };
    
    # Performance validation
    performance = {
      swapSize = {
        assertion = config.swapDevices != [] || config.zramSwap.enable;
        message = "Consider enabling swap or zram for better performance";
        severity = "info";
      };
    };
    
    # User validation
    users = {
      noEmptyPasswords = {
        assertion = !config.users.mutableUsers || 
          (builtins.all (user: user.hashedPassword != null || user.passwordFile != null) 
           (builtins.attrValues config.users.users));
        message = "Users should have passwords set";
        severity = "error";
      };
    };
  };

  # Run validation rules
  runValidation = rules: let
    results = lib.flatten (lib.mapAttrsToList (category: categoryRules:
      lib.mapAttrsToList (name: rule: {
        inherit (rule) assertion message severity;
        name = "${category}.${name}";
        passed = rule.assertion;
      }) categoryRules
    ) rules);
    
    errors = builtins.filter (r: !r.passed && r.severity == "error") results;
    warnings = builtins.filter (r: !r.passed && r.severity == "warning") results;
    info = builtins.filter (r: !r.passed && r.severity == "info") results;
    
  in {
    inherit results errors warnings info;
    hasErrors = errors != [];
    hasWarnings = warnings != [];
  };

in {
  options = {
    validation = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable configuration validation";
      };
      
      strictMode = mkOption {
        type = types.bool;
        default = false;
        description = "Treat warnings as errors";
      };
    };
  };

  config = let
    validation = runValidation validationRules;
  in lib.mkIf config.validation.enable {
    # Convert validation results to assertions
    assertions = map (error: {
      assertion = false;
      message = "Validation Error [${error.name}]: ${error.message}";
    }) validation.errors ++ 
    (if config.validation.strictMode then 
      map (warning: {
        assertion = false;
        message = "Validation Warning [${warning.name}]: ${warning.message}";
      }) validation.warnings
    else []);

    # Add warnings to system
    warnings = map (warning: 
      "Validation Warning [${warning.name}]: ${warning.message}"
    ) validation.warnings ++
    map (info:
      "Validation Info [${info.name}]: ${info.message}"  
    ) validation.info;
    
    # Export validation results for other tools
    _module.args.validationResults = validation;
  };
}