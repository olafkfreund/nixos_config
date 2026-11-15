{ config, lib, pkgs, ... }:
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
      spiceGuestAgent = mkEnableOption ''
        the spice-vdagent guest daemon. Only meaningful when THIS machine is
        itself a SPICE/VM guest. On a physical host it has no SPICE session
        and logs "Error getting active session: No data available" on a
        tight loop, so it stays off even when SPICE (USB redirection / client
        tools for running VMs locally) is enabled'';
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

  config = {
    # Baseline tools available on any host enabling features.development.
    # Without this, hosts with development features but no other package-set
    # trigger would lack git/curl/jq at the system level.
    environment.systemPackages = lib.mkIf config.features.development.enable [
      pkgs.git
      pkgs.curl
      pkgs.jq
    ];

    # Docker keeps its own modules.containers.docker root (out of scope for #2934);
    # this line is what makes features.virtualization.docker do anything.
    modules.containers.docker.enable =
      lib.mkIf config.features.virtualization.enable config.features.virtualization.docker;

    programs = {
      lazygit.enable = config.features.programs.lazygit;
      thunderbird.enable = config.features.programs.thunderbird;
    };
  };
}
