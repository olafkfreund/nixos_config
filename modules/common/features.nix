{ lib, ... }:
let inherit (lib) mkOption mkEnableOption types; in {
  options.features = {
    development = {
      enable = mkEnableOption "Enable development tools";

      # Granular enablement options
      python = mkEnableOption "Python development";
      go = mkEnableOption "Go development";
      nodejs = mkEnableOption "Node.js development";
      java = mkEnableOption "Java development";
      lua = mkEnableOption "Lua development";
      nix = mkEnableOption "Nix development";
      shell = mkEnableOption "Shell development";
      cargo = mkEnableOption "Cargo/Rust development";
      copilot-cli = mkEnableOption "GitHub Copilot CLI";
      github = mkEnableOption "GitHub development";
      devshell = mkEnableOption "DevShell development";
      precommit = mkEnableOption "Pre-commit hooks and linting";
    };

    virtualization = {
      enable = mkEnableOption "Enable virtualization";
      docker = mkEnableOption "Enable Docker";
      podman = mkEnableOption "Enable Podman";
      incus = mkEnableOption "Enable Incus containers";
      spice = mkEnableOption "Enable SPICE";
      libvirt = mkEnableOption "Enable libvirt";
    };

    cloud = {
      enable = mkEnableOption "Enable cloud tools";
      aws = mkEnableOption "Enable AWS tools";
      azure = mkEnableOption "Enable Azure tools";
      google = mkEnableOption "Enable Google Cloud tools";
      k8s = mkEnableOption "Enable Kubernetes tools";
      terraform = mkEnableOption "Enable Terraform tools";
    };

    security = {
      enable = mkEnableOption "Enable security tools";
      onepassword = mkEnableOption "Enable 1Password";
      gnupg = mkEnableOption "Enable GnuPG";
    };

    ai = {
      enable = mkEnableOption "Enable AI tools";
      antigravity-cli = mkEnableOption "Enable Google Antigravity CLI (agy) — replaces gemini-cli (EOL 2026-06-18)";
      claude-desktop = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Claude Desktop GUI application";
      };
    };

    programs = {
      lazygit = mkEnableOption "Enable LazyGit";
      thunderbird = mkEnableOption "Enable Thunderbird";
      obsidian = mkEnableOption "Enable Obsidian";
      office = mkEnableOption "Enable Office tools";
      webcam = mkEnableOption "Enable Webcam tools";
      print = mkEnableOption "Enable Printing";
    };

    media = {
      droidcam = mkEnableOption "Enable DroidCam";
    };
  };
}
