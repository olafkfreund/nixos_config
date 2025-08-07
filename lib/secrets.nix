# Enhanced secrets management with validation and organization
{
  lib,
  config,
  ...
}: let
  inherit (lib) mkOption types;
  
  # Secret categories and validation
  secretCategories = {
    user-passwords = {
      pattern = "user-password-*";
      required = true;
      description = "User account passwords";
      validation = secret: {
        assertion = builtins.match "user-password-[a-zA-Z0-9_-]+" secret != null;
        message = "User password secrets must follow pattern: user-password-<username>";
      };
    };
    
    service-keys = {
      pattern = "service-*-key";
      required = false;
      description = "Service API keys and credentials";
      validation = secret: {
        assertion = builtins.match "service-[a-zA-Z0-9_-]+-key" secret != null;
        message = "Service key secrets must follow pattern: service-<name>-key";
      };
    };
    
    certificates = {
      pattern = "*-cert.pem";
      required = false;
      description = "SSL/TLS certificates";
      validation = secret: {
        assertion = lib.hasSuffix "-cert.pem" secret;
        message = "Certificate secrets must end with -cert.pem";
      };
    };
    
    ssh-keys = {
      pattern = "ssh-*";
      required = false;
      description = "SSH private keys";
      validation = secret: {
        assertion = lib.hasPrefix "ssh-" secret;
        message = "SSH key secrets must start with ssh-";
      };
    };
  };

  # Validate secrets against categories
  validateSecrets = secrets: let
    validateSecret = secretName: let
      category = lib.findFirst 
        (cat: builtins.match secretCategories.${cat}.pattern secretName != null)
        null
        (lib.attrNames secretCategories);
    in 
      if category != null then
        secretCategories.${category}.validation secretName
      else {
        assertion = false;
        message = "Secret '${secretName}' doesn't match any known category pattern";
      };
      
    results = map validateSecret (lib.attrNames secrets);
    failures = builtins.filter (r: !r.assertion) results;
  in {
    isValid = failures == [];
    errors = map (f: f.message) failures;
  };

  # Secret access control helpers
  mkSecretAccess = {
    hosts ? [],
    users ? [],
    mode ? "0400",
    owner ? "root",
    group ? "root",
  }: {
    publicKeys = 
      # Host keys
      (map (host: config.age.secrets.${host}.publicKey or null) hosts) ++
      # User keys  
      (map (user: config.age.secrets.${user}.publicKey or null) users);
    
    # Runtime configuration
    mode = mode;
    owner = owner;
    group = group;
  };

  # Common secret templates
  secretTemplates = {
    userPassword = user: {
      name = "user-password-${user}";
      access = mkSecretAccess {
        users = [user];
        mode = "0600";
        owner = user;
      };
    };
    
    serviceKey = service: hosts: {
      name = "service-${service}-key";
      access = mkSecretAccess {
        inherit hosts;
        mode = "0600";
      };
    };
    
    sshKey = keyName: user: {
      name = "ssh-${keyName}";
      access = mkSecretAccess {
        users = [user];
        mode = "0600";
        owner = user;
      };
    };
  };

in {
  options = {
    secretsConfig = {
      validation = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable secrets validation";
        };
        
        strictNaming = mkOption {
          type = types.bool;
          default = true;
          description = "Enforce strict naming conventions for secrets";
        };
      };
      
      categories = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            required = mkOption {
              type = types.bool;
              default = false;
              description = "Whether this category is required";
            };
            
            hosts = mkOption {
              type = types.listOf types.str;
              default = [];
              description = "Hosts that need access to this category";
            };
          };
        });
        default = {};
        description = "Secret category configuration";
      };
    };
  };

  config = let
    secretValidation = validateSecrets config.age.secrets;
  in lib.mkIf config.secretsConfig.validation.enable {
    assertions = [
      {
        assertion = !config.secretsConfig.validation.strictNaming || secretValidation.isValid;
        message = ''
          Secret validation failed:
          ${lib.concatStringsSep "\n" secretValidation.errors}
        '';
      }
    ];

    # Export helpers for use in configuration
    _module.args.secretTemplates = secretTemplates;
    _module.args.mkSecretAccess = mkSecretAccess;
    _module.args.secretCategories = secretCategories;
  };
}