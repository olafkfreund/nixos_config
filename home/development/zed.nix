{
  config,
  lib,
  pkgs-unstable,
  ...
}:
with lib; let
  cfg = config.editor.zed-editor;
in {
  options.editor.zed-editor = {
    enable = mkEnableOption "zed-editor"; # Fixed syntax to use string description
  };

  config = mkIf cfg.enable {
    programs.zed-editor = {
      enable = true;
      package = pkgs-unstable.zed-editor;
      userSettings = {
        features = {
          inline_prediction_provider = "copilot";
          show_edit_predictions = true;
          edit_prediction_provider = "copilot";
          copilot = true;
        };
        telemetry = {
          metrics = false;
        };
        lsp = {
          rust_analyzer = {
            binary = {path_lookup = true;};
          };
        };
        languages = {
          Nix = {
            language_servers = ["nixd"];
            formatter = {
              external = {
                command = "alejandra";
                arguments = ["-q" "-"];
              };
            };
          };
          Python = {
            language_servers = ["pyright"];
            formatter = {
              external = {
                command = "black";
                arguments = ["-"];
              };
            };
          };
          Go = {
            language_servers = ["gopls"];
            formatter = {
              external = {
                command = "gofmt";
                arguments = [];
              };
            };
            tab_size = 8;
            preferred_line_length = 100;
            auto_indent_using_language_server = true;
          };
        };
        assistant = {
          version = "2";
          default_model = {
            provider = "zed.dev";
            model = "claude-3-5-sonnet-latest";
          };
        };
        language_models = {
          anthropic = {
            version = "1";
            api_url = "https://api.anthropic.com";
          };
          openai = {
            version = "1";
            api_url = "https://api.openai.com/v1";
          };
          ollama = {
            api_url = "http://localhost:11434";
          };
          google = {
            version = "1";
            api_url = "https://generativelanguage.googleapis.com/v1";
          };
        };
        ssh_connections = [];
        auto_update = false;
        format_on_save = "on";
        vim_mode = true;
        load_direnv = "shell_hook";
        theme = lib.mkForce "Gruvbox Dark Soft";
        # buffer_font_family = lib.mkForce "FiraCode Nerd Font";
        # ui_font_size = lib.mkForce 16;
        # buffer_font_size = 16;
      };
    };
  };
}
