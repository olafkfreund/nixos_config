{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  # Home Manager configuration for workstation template

  # Desktop programs
  programs = {
    # Terminal
    kitty = {
      enable = true;
      settings = {
        font_family = "FiraCode Nerd Font";
        font_size = 12;
        background_opacity = "0.9";
      };
    };

    # Browser
    firefox = {
      enable = true;
      profiles.default = {
        bookmarks = [];
        settings = {
          "browser.startup.homepage" = "about:home";
          "browser.newtabpage.enabled" = true;
        };
      };
    };

    # Git
    git = {
      enable = true;
      userName = "Your Name"; # Change this
      userEmail = "your.email@example.com"; # Change this
      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
      };
    };

    # Shell
    zsh = {
      enable = true;
      enableCompletion = true;
      enableAutosuggestions = true;
      syntaxHighlighting.enable = true;

      shellAliases = {
        ll = "ls -l";
        la = "ls -la";
        ".." = "cd ..";
        "..." = "cd ../..";

        # NixOS aliases
        nrs = "sudo nixos-rebuild switch --flake .";
        nrb = "nixos-rebuild build --flake .";
        hms = "home-manager switch --flake .";
      };

      history = {
        size = 10000;
        path = "${config.xdg.dataHome}/zsh/history";
      };
    };

    # Text editor
    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
    };

    # Development tools
    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
  };

  # Desktop services
  services = {
    # Notification daemon
    dunst = {
      enable = true;
      settings = {
        global = {
          width = 300;
          height = 300;
          offset = "30x50";
          origin = "top-right";
          transparency = 10;
          frame_color = "#eceff1";
          font = "FiraCode Nerd Font 10";
        };
      };
    };
  };

  # XDG configuration
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
    };
  };

  # Home packages
  home.packages = with pkgs; [
    # Development
    git-ui
    lazygit

    # System utilities
    btop
    eza
    bat
    ripgrep
    fd
    fzf

    # Desktop utilities
    rofi-wayland
    waybar
    hyprpaper
    grim
    slurp
    wl-clipboard

    # Applications
    thunar
    pavucontrol
    blueman
  ];

  # Dotfiles and configuration
  home.file = {
    # Hyprland configuration
    ".config/hypr/hyprland.conf".text = ''
      # Basic Hyprland configuration

      # Monitor configuration (adjust as needed)
      monitor=,preferred,auto,1

      # Input configuration
      input {
          kb_layout = us
          follow_mouse = 1
          touchpad {
              natural_scroll = yes
          }
          sensitivity = 0
      }

      # General settings
      general {
          gaps_in = 5
          gaps_out = 20
          border_size = 2
          col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
          col.inactive_border = rgba(595959aa)
          layout = dwindle
      }

      # Decoration
      decoration {
          rounding = 10

          blur {
              enabled = true
              size = 8
              passes = 1
          }

          drop_shadow = yes
          shadow_range = 4
          shadow_render_power = 3
          col.shadow = rgba(1a1a1aee)
      }

      # Animations
      animations {
          enabled = yes

          bezier = myBezier, 0.05, 0.9, 0.1, 1.05

          animation = windows, 1, 7, myBezier
          animation = windowsOut, 1, 7, default, popin 80%
          animation = border, 1, 10, default
          animation = borderangle, 1, 8, default
          animation = fade, 1, 7, default
          animation = workspaces, 1, 6, default
      }

      # Layouts
      dwindle {
          pseudotile = yes
          preserve_split = yes
      }

      # Window rules
      windowrule = float, ^(pavucontrol)$
      windowrule = float, ^(blueman-manager)$

      # Keybindings
      $mainMod = SUPER

      bind = $mainMod, Return, exec, kitty
      bind = $mainMod, Q, killactive,
      bind = $mainMod, M, exit,
      bind = $mainMod, E, exec, thunar
      bind = $mainMod, V, togglefloating,
      bind = $mainMod, R, exec, rofi -show drun
      bind = $mainMod, P, pseudo,
      bind = $mainMod, J, togglesplit,

      # Move focus
      bind = $mainMod, left, movefocus, l
      bind = $mainMod, right, movefocus, r
      bind = $mainMod, up, movefocus, u
      bind = $mainMod, down, movefocus, d

      # Switch workspaces
      bind = $mainMod, 1, workspace, 1
      bind = $mainMod, 2, workspace, 2
      bind = $mainMod, 3, workspace, 3
      bind = $mainMod, 4, workspace, 4
      bind = $mainMod, 5, workspace, 5

      # Move active window to workspace
      bind = $mainMod SHIFT, 1, movetoworkspace, 1
      bind = $mainMod SHIFT, 2, movetoworkspace, 2
      bind = $mainMod SHIFT, 3, movetoworkspace, 3
      bind = $mainMod SHIFT, 4, movetoworkspace, 4
      bind = $mainMod SHIFT, 5, movetoworkspace, 5

      # Screenshot
      bind = , Print, exec, grim -g "$(slurp)" - | wl-copy

      # Audio
      bind = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
      bind = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
      bind = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

      # Startup applications
      exec-once = waybar
      exec-once = hyprpaper
      exec-once = dunst
    '';

    # Waybar configuration
    ".config/waybar/config".text = builtins.toJSON {
      layer = "top";
      position = "top";
      height = 30;

      modules-left = ["hyprland/workspaces"];
      modules-center = ["clock"];
      modules-right = ["pulseaudio" "network" "battery" "tray"];

      "hyprland/workspaces" = {
        disable-scroll = true;
        all-outputs = true;
      };

      clock = {
        format = "{:%Y-%m-%d %H:%M}";
        tooltip-format = "{:%Y-%m-%d | %H:%M:%S}";
      };

      pulseaudio = {
        format = "{volume}% {icon}";
        format-bluetooth = "{volume}% {icon}";
        format-muted = "";
        format-icons = {
          headphone = "";
          hands-free = "";
          headset = "";
          phone = "";
          portable = "";
          car = "";
          default = ["" ""];
        };
        on-click = "pavucontrol";
      };

      network = {
        format-wifi = "{essid} ({signalStrength}%) ";
        format-ethernet = "{ifname}: {ipaddr}/{cidr} ";
        format-disconnected = "Disconnected ⚠";
        tooltip-format = "{ifname}: {ipaddr}";
      };

      battery = {
        states = {
          good = 95;
          warning = 30;
          critical = 15;
        };
        format = "{capacity}% {icon}";
        format-charging = "{capacity}% ";
        format-plugged = "{capacity}% ";
        format-icons = ["" "" "" "" ""];
      };

      tray = {
        icon-size = 21;
        spacing = 10;
      };
    };
  };

  # Session variables
  home.sessionVariables = {
    EDITOR = "nvim";
    BROWSER = "firefox";
    TERMINAL = "kitty";
  };

  # Home Manager state version
  home.stateVersion = "24.11";
}
