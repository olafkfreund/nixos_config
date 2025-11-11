{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs;
in
{
  options.programs = {
    k9s.desktopEntry = {
      enable = mkEnableOption "k9s desktop entry for application launchers";
    };

    claude-code.desktopEntry = {
      enable = mkEnableOption "Claude Code desktop entry for application launchers";
    };

    neovim.desktopEntry = {
      enable = mkEnableOption "Neovim desktop entry for application launchers and file associations";
    };
  };

  config = mkMerge [
    # K9s Desktop Entry
    (mkIf cfg.k9s.desktopEntry.enable {
      xdg.desktopEntries.k9s = {
        name = "K9s";
        genericName = "Kubernetes CLI Manager";
        comment = "Kubernetes CLI To Manage Your Clusters In Style";
        exec = "${pkgs.k9s}/bin/k9s";
        icon = "k9s";
        terminal = true;
        type = "Application";
        categories = [ "System" "TerminalEmulator" "Development" ];
        keywords = [ "kubernetes" "k8s" "cluster" "management" "container" "pod" ];
      };
    })

    # Claude Code Desktop Entry
    (mkIf cfg.claude-code.desktopEntry.enable {
      xdg.desktopEntries.claude-code = {
        name = "Claude Code";
        genericName = "AI-Powered Code Assistant";
        comment = "Claude Code CLI for AI-assisted development";
        exec = "claude";
        icon = "claude-code";
        terminal = true;
        type = "Application";
        categories = [ "Development" "TextEditor" "Utility" ];
        keywords = [ "ai" "claude" "code" "assistant" "development" "anthropic" ];
      };
    })

    # Neovim Desktop Entry with File Associations
    (mkIf cfg.neovim.desktopEntry.enable {
      xdg.desktopEntries.neovim = {
        name = "Neovim";
        genericName = "Text Editor";
        comment = "Hyperextensible Vim-based text editor";
        exec = "nvim %F";
        icon = "nvim";
        terminal = true;
        type = "Application";
        categories = [ "Development" "TextEditor" "Utility" ];
        keywords = [ "vim" "neovim" "editor" "text" "code" ];
        mimeType = [
          "text/plain"
          "text/x-csrc"
          "text/x-c++src"
          "text/x-python"
          "text/x-shellscript"
          "text/x-markdown"
          "text/x-yaml"
          "application/x-yaml"
          "application/json"
          "text/x-rust"
          "text/x-go"
          "text/x-java"
          "text/x-lua"
          "text/x-makefile"
          "text/x-nix"
        ];
      };
    })
  ];
}
