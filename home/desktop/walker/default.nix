{ pkgs
, config
, lib
, ...
}:
with lib; let
  cfg = config.desktop.walker;
in
{
  options.desktop.walker = {
    enable = mkEnableOption {
      default = false;
      description = "Enable Walker launcher";
    };

    runAsService = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to run Walker as a background service for faster startup";
    };
  };

  config = mkIf cfg.enable {
    # Install Walker as a package since programs.walker doesn't exist in home-manager
    home.packages = [ pkgs.walker ];

    # Create Walker configuration manually via xdg.configFile
    xdg.configFile."walker/config.toml".text = ''
      [search]
      placeholder = "Search..."

      [ui]
      fullscreen = false
      width = 1000
      height = 800
      icon_theme = "Adwaita"
      icon_size = 26
      show_search = true

      [ui.anchors]
      left = false
      right = false
      top = false
      bottom = false

      [ui.margins]
      top = 20
      bottom = 20
      left = 20
      right = 20

      [list]
      height = 650
      width = 960
      margin = 20

      hotreload_theme = true
      theme = "gruvbox"
    '';

    # Add auto-start for Hyprland if runAsService is enabled
    wayland.windowManager.hyprland.extraConfig = mkIf (cfg.runAsService && config.wayland.windowManager.hyprland.enable) ''
      exec-once=walker --gapplication-service
    '';

    # Add auto-start for Sway if runAsService is enabled
    wayland.windowManager.sway.config.startup = mkIf (cfg.runAsService && config.wayland.windowManager.sway.enable) [
      { command = "walker --gapplication-service"; }
    ];

    # Gruvbox theme TOML layout configuration (exact copy of default.toml with Gruvbox marker color)
    xdg.configFile."walker/themes/gruvbox.toml".text = ''
      [ui.anchors]
      bottom = true
      left = true
      right = true
      top = true

      [ui.window]
      h_align = "fill"
      v_align = "fill"

      [ui.window.box]
      h_align = "center"
      width = 450

      [ui.window.box.bar]
      orientation = "horizontal"
      position = "end"

      [ui.window.box.bar.entry]
      h_align = "fill"
      h_expand = true

      [ui.window.box.bar.entry.icon]
      h_align = "center"
      h_expand = true
      pixel_size = 24
      theme = ""

      [ui.window.box.margins]
      top = 200

      [ui.window.box.ai_scroll]
      name = "aiScroll"
      h_align = "fill"
      v_align = "fill"
      max_height = 300
      min_width = 400
      height = 300
      width = 400

      [ui.window.box.ai_scroll.margins]
      top = 8

      [ui.window.box.ai_scroll.list]
      name = "aiList"
      orientation = "vertical"
      width = 400
      spacing = 10

      [ui.window.box.ai_scroll.list.item]
      name = "aiItem"
      h_align = "fill"
      v_align = "fill"
      x_align = 0
      y_align = 0
      wrap = true

      [ui.window.box.scroll.list]
      marker_color = "#8ec07c"
      max_height = 300
      max_width = 400
      min_width = 400
      width = 400

      [ui.window.box.scroll.list.item.activation_label]
      h_align = "fill"
      v_align = "fill"
      width = 20
      x_align = 0.5
      y_align = 0.5

      [ui.window.box.scroll.list.item.icon]
      pixel_size = 26
      theme = ""

      [ui.window.box.scroll.list.margins]
      top = 8

      [ui.window.box.search.prompt]
      name = "prompt"
      icon = "edit-find"
      theme = ""
      pixel_size = 18
      h_align = "center"
      v_align = "center"

      [ui.window.box.search.clear]
      name = "clear"
      icon = "edit-clear"
      theme = ""
      pixel_size = 18
      h_align = "center"
      v_align = "center"

      [ui.window.box.search.input]
      h_align = "fill"
      h_expand = true
      icons = true

      [ui.window.box.search.spinner]
      hide = true
    '';

    # Gruvbox theme CSS (exact copy of default.css with Gruvbox colors)
    xdg.configFile."walker/themes/gruvbox.css".text = ''
      /* Gruvbox colors for Walker theme */
      @define-color foreground #ebdbb2;
      @define-color background #282828;
      @define-color color1 #8ec07c;

      #window,
      #box,
      #aiScroll,
      #aiList,
      #search,
      #password,
      #input,
      #prompt,
      #clear,
      #typeahead,
      #list,
      child,
      scrollbar,
      slider,
      #item,
      #text,
      #label,
      #bar,
      #sub,
      #activationlabel {
        all: unset;
      }

      #cfgerr {
        background: rgba(255, 0, 0, 0.4);
        margin-top: 20px;
        padding: 8px;
        font-size: 1.2em;
      }

      #window {
        color: @foreground;
      }

      #box {
        border-radius: 2px;
        background: @background;
        padding: 32px;
        border: 1px solid lighter(@background);
        box-shadow:
          0 19px 38px rgba(0, 0, 0, 0.3),
          0 15px 12px rgba(0, 0, 0, 0.22);
      }

      #search {
        box-shadow:
          0 1px 3px rgba(0, 0, 0, 0.1),
          0 1px 2px rgba(0, 0, 0, 0.22);
        background: lighter(@background);
        padding: 8px;
      }

      #prompt {
        margin-left: 4px;
        margin-right: 12px;
        color: @foreground;
        opacity: 0.2;
      }

      #clear {
        color: @foreground;
        opacity: 0.8;
      }

      #password,
      #input,
      #typeahead {
        border-radius: 2px;
      }

      #input {
        background: none;
      }

      #password {
      }

      #spinner {
        padding: 8px;
      }

      #typeahead {
        color: @foreground;
        opacity: 0.8;
      }

      #input placeholder {
        opacity: 0.5;
      }

      #list {
      }

      child {
        padding: 8px;
        border-radius: 2px;
      }

      child:selected,
      child:hover {
        background: alpha(@color1, 0.4);
      }

      #item {
      }

      #icon {
        margin-right: 8px;
      }

      #text {
      }

      #label {
        font-weight: 500;
      }

      #sub {
        opacity: 0.5;
        font-size: 0.8em;
      }

      #activationlabel {
      }

      #bar {
      }

      .barentry {
      }

      .activation #activationlabel {
      }

      .activation #text,
      .activation #icon,
      .activation #search {
        opacity: 0.5;
      }

      .aiItem {
        padding: 10px;
        border-radius: 2px;
        color: @foreground;
        background: @background;
      }

      .aiItem.user {
        padding-left: 0;
        padding-right: 0;
      }

      .aiItem.assistant {
        background: lighter(@background);
      }
    '';
  };
}
