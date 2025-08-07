# Enhanced System Information and Monitoring
# Includes neofetch configuration plus system monitoring utilities
{
  pkgs,
  lib,
  ...
}:
with lib;
let
  # Feature flags for system monitoring
  cfg = {
    neofetch = {
      enable = true;
      customLogo = true;
      imageSupport = true;
    };
    
    systemMonitors = {
      btop = true;
      htop = true;
      nvtop = true;
      iotop = true;
      fastfetch = true;  # Modern neofetch alternative
    };
    
    utilities = {
      processTools = true;   # procs, killall, etc.
      diskTools = true;      # ncdu, dust, duf, etc.
      networkTools = true;   # bandwhich, nethogs, etc.
      textTools = true;      # ripgrep, fd, jq, etc.
    };
  };

in {
  # Enhanced system monitoring packages
  home.packages = with pkgs; flatten [
    # Core system info
    (optionals cfg.neofetch.enable [ neofetch ])
    (optionals cfg.systemMonitors.fastfetch [ fastfetch ])
    
    # System monitors
    (optionals cfg.systemMonitors.btop [ btop ])
    (optionals cfg.systemMonitors.htop [ htop ])
    (optionals cfg.systemMonitors.nvtop [ nvtopPackages.full ])
    (optionals cfg.systemMonitors.iotop [ iotop ])
    
    # Process tools
    (optionals cfg.utilities.processTools [ procs pstree lsof killall ])
    
    # Disk utilities
    (optionals cfg.utilities.diskTools [ ncdu dust duf tree ])
    
    # Network tools  
    (optionals cfg.utilities.networkTools [ bandwhich nethogs iftop nload speedtest-cli ])
    
    # Text processing
    (optionals cfg.utilities.textTools [ ripgrep fd jq yq-go hyperfine tokei ])
  ];
  
  # Enhanced btop configuration
  programs.btop = mkIf cfg.systemMonitors.btop {
    enable = true;
    settings = {
      color_theme = mkDefault "gruvbox_dark_v2";
      theme_background = false;
      vim_keys = true;
      rounded_corners = true;
      graph_symbol = "braille";
      shown_boxes = "cpu mem net proc";
      update_ms = 2000;
      proc_sorting = "cpu lazy";
      proc_tree = false;
      proc_colors = true;
      proc_gradient = true;
      cpu_graph_upper = "total";
      cpu_single_graph = false;
      show_uptime = true;
      check_temp = true;
      show_coretemp = true;
      show_cpu_freq = true;
      mem_graphs = true;
      show_swap = true;
      show_disks = true;
      net_auto = true;
      net_sync = false;
    };
  };
  
  # Custom monitoring scripts
  home.file = mkMerge [
    # System dashboard script
    {
      ".local/bin/system-dashboard" = {
        text = ''
          #!/bin/sh
          # Enhanced system monitoring dashboard
          echo "╭─────────────────────────────────────╮"
          echo "│          System Dashboard           │"
          echo "╰─────────────────────────────────────╯"
          echo
          
          # System info
          echo "📊 System Information:"
          ${optionalString cfg.systemMonitors.fastfetch "${pkgs.fastfetch}/bin/fastfetch --config small"}
          ${optionalString (!cfg.systemMonitors.fastfetch && cfg.neofetch.enable) "${pkgs.neofetch}/bin/neofetch --disable packages"}
          echo
          
          # Resource usage
          echo "💾 Storage Usage:"
          ${optionalString cfg.utilities.diskTools "${pkgs.duf}/bin/duf"}
          echo
          
          # Process overview
          echo "⚡ Top Processes:"
          ${optionalString cfg.utilities.processTools "${pkgs.procs}/bin/procs --tree --color always | head -15"}
          echo
          
          # Network activity
          echo "🌐 Network Activity:"
          ${optionalString cfg.utilities.networkTools "${pkgs.bandwhich}/bin/bandwhich --interfaces"}
        '';
        executable = true;
      };
    }
    
    # Quick system info script
    {
      ".local/bin/sysinfo" = {
        text = ''
          #!/bin/sh
          # Quick system information
          ${optionalString cfg.systemMonitors.fastfetch "${pkgs.fastfetch}/bin/fastfetch"}
          ${optionalString (!cfg.systemMonitors.fastfetch && cfg.neofetch.enable) "${pkgs.neofetch}/bin/neofetch"}
        '';
        executable = true;
      };
    }
    
    # Neofetch configuration
    {
      ".config/neofetch/config.conf".text = ''
    print_info() {
        prin "$(color 6)  NIXOS "
        info underline
        info "$(color 7)  VER" kernel
        info "$(color 2)  UP " uptime
        info "$(color 4)  PKG" packages
        info "$(color 6)  DE " de
        info "$(color 5)  TER" term
        info "$(color 3)  CPU" cpu
        info "$(color 7)  GPU" gpu
        info "$(color 5)  MEM" memory
        prin " "
        prin "$(color 1) $(color 2) $(color 3) $(color 4) $(color 5) $(color 6) $(color 7) $(color 8)"
    }
    distro_shorthand="on"
    memory_unit="gib"
    cpu_temp="C"
    separator=" $(color 4)>"
    stdout="off"
    image_backend="kitty"
    image_source=$HOME/Pictures/wallpapers/gruvbox/finalizer.png
    image_size="100px"
    crop_mode="normal"
    crop_offset="west"
  '';
    }
  ];
}
