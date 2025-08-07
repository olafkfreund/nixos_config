# Enhanced Zed Editor Configuration
# Integrated with unified language support and enhanced AI features
{
  config,
  lib,
  pkgs-unstable,
  ...
}:
with lib; let
  cfg = config.editor.zed-editor;
  
  # Enhanced feature configuration
  features = {
    # AI and language support
    ai = {
      copilot = true;
      claude = true;
      ollama = false;
      multiple_providers = true;
    };
    
    # Language integration (from languages.nix)
    languages = {
      nix = { enable = true; lsp = "nixd"; formatter = "alejandra"; };
      python = { enable = true; lsp = "pyright"; formatter = "black"; };
      javascript = { enable = true; lsp = "typescript-language-server"; formatter = "prettier"; };
      go = { enable = true; lsp = "gopls"; formatter = "gofmt"; };
      rust = { enable = true; lsp = "rust-analyzer"; formatter = "rustfmt"; };
    };
    
    # Editor enhancements
    editor = {
      vim_mode = true;
      format_on_save = true;
      auto_update = false;
      theme = "gruvbox-dark";
      direnv = true;
    };
    
    # Development workflow
    workflow = {
      git_integration = true;
      project_search = true;
      terminal = true;
      collaboration = false;
    };
  };
  
  # Generate language configurations from unified language support
  languageConfigs = mapAttrs (name: lang: 
    optionalAttrs lang.enable {
      language_servers = [ lang.lsp ];
      formatter = {
        external = {
          command = lang.formatter;
          arguments = 
            if lang.formatter == "alejandra" then [ "-q" "-" ]
            else if lang.formatter == "black" then [ "-" ]
            else if lang.formatter == "prettier" then [ "--stdin-filepath" ".${name}" ]
            else [];
        };
      };
    } // optionalAttrs (name == "go") {
      tab_size = 8;
      preferred_line_length = 100;
      auto_indent_using_language_server = true;
    }
  ) (filterAttrs (_n: l: l.enable) features.languages);
  
in {
  options.editor.zed-editor = {
    enable = mkEnableOption "zed-editor"; # Fixed syntax to use string description
  };

  config = mkIf cfg.enable {
    # Enhanced Zed Editor with unified language support integration
    programs.zed-editor = {
      enable = true;
      package = pkgs-unstable.zed-editor;
      
      userSettings = {
        # Enhanced AI features with multiple providers
        features = mkMerge [
          (mkIf features.ai.copilot {
            inline_prediction_provider = "copilot";
            show_edit_predictions = true;
            edit_prediction_provider = "copilot";
            copilot = true;
          })
          {
            # Enhanced editor features
            code_actions_on_format = true;
            auto_signature_help = true;
            show_call_status_icon = true;
            inline_completions = true;
          }
        ];
        
        # Privacy and telemetry
        telemetry = {
          metrics = false;
          diagnostics = false;
        };
        
        # Enhanced LSP configuration with unified language support
        lsp = mkMerge [
          # Rust analyzer with enhanced settings
          (mkIf features.languages.rust.enable {
            rust_analyzer = {
              binary = { path_lookup = true; };
              initialization_options = {
                cargo = { allFeatures = true; };
                checkOnSave = { command = "clippy"; };
                procMacro = { enable = true; };
              };
            };
          })
          
          # Nixd with comprehensive configuration
          (mkIf features.languages.nix.enable {
            nixd = {
              binary = { path_lookup = true; };
              initialization_options = {
                formatting = { command = [ "alejandra" ]; };
                options = {
                  nixos = { expr = "(builtins.getFlake \"git+file://\" + toString ~/.config/nixos).nixosConfigurations.p620.options"; };
                  home_manager = { expr = "(builtins.getFlake \"git+file://\" + toString ~/.config/nixos).homeConfigurations.\"${config.home.username}@p620\".options"; };
                };
              };
            };
          })
          
          # Enhanced language server configurations
          {
            # Global LSP settings
            inlay_hints = {
              enabled = true;
              show_type_hints = true;
              show_parameter_hints = true;
            };
          }
        ];
        
        # Dynamic language configurations from unified language support
        languages = mkMerge [
          # Core language mappings (capitalized for Zed)
          (mkIf features.languages.nix.enable {
            "Nix" = languageConfigs.nix;
          })
          (mkIf features.languages.python.enable {
            "Python" = languageConfigs.python;
          })
          (mkIf features.languages.javascript.enable {
            "JavaScript" = languageConfigs.javascript;
            "TypeScript" = languageConfigs.javascript;
            "TSX" = languageConfigs.javascript;
            "JSX" = languageConfigs.javascript;
          })
          (mkIf features.languages.go.enable {
            "Go" = languageConfigs.go;
          })
          (mkIf features.languages.rust.enable {
            "Rust" = languageConfigs.rust // {
              # Rust-specific enhancements
              hard_tabs = false;
              tab_size = 4;
              preferred_line_length = 100;
              language_servers = [ "rust-analyzer" ];
            };
          })
        ];
        
        # Enhanced AI assistant configuration
        assistant = mkMerge [
          (mkIf features.ai.claude {
            version = "2";
            default_model = {
              provider = "zed.dev";
              model = "claude-3-5-sonnet-latest";
            };
            dock = "right";
            default_width = 400;
            provider_config = {
              anthropic = {
                low_speed_timeout_in_seconds = 60;
                max_tokens = 4096;
              };
            };
          })
        ];
        
        # Enhanced language model providers
        language_models = mkMerge [
          (mkIf features.ai.multiple_providers {
            anthropic = {
              version = "1";
              api_url = "https://api.anthropic.com";
              low_speed_timeout_in_seconds = 60;
            };
            openai = {
              version = "1";
              api_url = "https://api.openai.com/v1";
              low_speed_timeout_in_seconds = 60;
            };
            google = {
              version = "1";
              api_url = "https://generativelanguage.googleapis.com/v1";
            };
          })
          (mkIf features.ai.ollama {
            ollama = {
              api_url = "http://localhost:11434";
              low_speed_timeout_in_seconds = 30;
            };
          })
        ];
        
        # Enhanced editor settings
        auto_update = mkDefault features.editor.auto_update;
        format_on_save = mkIf features.editor.format_on_save "on";
        vim_mode = mkDefault features.editor.vim_mode;
        load_direnv = mkIf features.editor.direnv "shell_hook";
        theme = mkDefault "Gruvbox Dark Soft";
        
        # Enhanced workflow settings
        ssh_connections = [];
        
        # Enhanced search and navigation
        project_panel = mkIf features.workflow.project_search {
          dock = "left";
          default_width = 240;
          file_icons = true;
          folder_icons = true;
          git_status = true;
          indent_size = 20;
        };
        
        # Enhanced terminal integration
        terminal = mkIf features.workflow.terminal {
          dock = "bottom";
          default_height = 320;
          font_family = "JetBrains Mono";
          font_size = 14;
          working_directory = "current_project_directory";
          shell = "zsh";
        };
        
        # Enhanced Git integration
        git = mkIf features.workflow.git_integration {
          git_gutter = "tracked_files";
          inline_blame = {
            enabled = true;
            delay_ms = 800;
          };
        };
        
        # Enhanced collaboration settings
        collaboration_panel = mkIf features.workflow.collaboration {
          dock = "left";
          default_width = 240;
        };
        
        # Font and UI customizations
        ui_font_family = mkDefault "Inter";
        ui_font_size = mkDefault 16;
        buffer_font_family = mkDefault "JetBrains Mono";
        buffer_font_size = mkDefault 14;
        buffer_line_height = mkDefault "comfortable";
        
        # Enhanced cursor and selection
        cursor_blink = false;
        show_whitespaces = "selection";
        
        # Enhanced file handling
        file_scan_exclusions = [
          "**/.git"
          "**/.direnv"
          "**/result"
          "**/node_modules"
          "**/.next"
          "**/target"
          "**/.cargo"
          "**/__pycache__"
          "**/.pytest_cache"
        ];
      };
    };
    
    # Enhanced shell integration
    home.shellAliases = mkMerge [
      { zed = "zed ."; }
      (mkIf features.workflow.git_integration {
        zg = "zed --wait";
        zgit = "GIT_EDITOR='zed --wait' git";
      })
    ];
    
    # Enhanced environment variables
    home.sessionVariables = mkMerge [
      (mkIf features.editor.direnv {
        DIRENV_LOG_FORMAT = "";
      })
    ];
  };
}
