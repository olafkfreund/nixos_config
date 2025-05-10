{
  config,
  lib,
  ...
}:
with lib; {
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
      ansible = mkEnableOption "Ansible development";
      cargo = mkEnableOption "Cargo/Rust development";
      github = mkEnableOption "GitHub development";
      devshell = mkEnableOption "DevShell development";
    };

    virtualization = {
      enable = mkEnableOption "Enable virtualization";
      docker = mkEnableOption "Enable Docker";
      podman = mkEnableOption "Enable Podman";
      incus = mkEnableOption "Enable Incus containers";
      spice = mkEnableOption "Enable SPICE";
      libvirt = mkEnableOption "Enable libvirt";
      sunshine = mkEnableOption "Enable Sunshine for streaming";
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

    networking = {
      enable = mkEnableOption "Enable networking";
      tailscale = mkEnableOption "Enable Tailscale VPN";
    };

    ai = {
      enable = mkEnableOption "Enable AI tools";
      ollama = mkEnableOption "Enable Ollama AI";
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
