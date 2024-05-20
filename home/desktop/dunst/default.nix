{
  inputs,
  pkgs,
  config,
  ...
}:{
  services.dunst = {
    enable = true;
    settings = {
      global = {
        background = "#${config.colorScheme.palette.base00}";
        foreground = "#${config.colorScheme.palette.base06}";
        monitor = 0;
        follow = "mouse";
        width = "(0,600)";
        height = 350;
        progress_bar = true;
        progress_bar_height = 25;
        progress_bar_frame_width = 3;
        progress_bar_min_width = 460;
        progress_bar_max_width = 480;
<<<<<<< HEAD
        # highlight = "#79dcaa";
=======
        highlight = "#79dcaa";
>>>>>>> 6f826e2188d86f7d0c76929d56e6cedb6863fd9d
        indicate_hidden = true;
        shrink = true;
        transparency = 5;
        separator_height = 5;
        padding = 10;
        horizontal_padding = 10;
        frame_width = 0;
        frame_color = "#${config.colorScheme.palette.base06}";
        sort = true;
        idle_threshold = 0;
<<<<<<< HEAD
        # font = "JetBrains Mono Nerd Font 13";
=======
        font = "JetBrains Mono Nerd Font 13";
>>>>>>> 6f826e2188d86f7d0c76929d56e6cedb6863fd9d
        line_height = 2;
        markup = "full";
        origin = "top-right";
        offset = "10x10";
        format = "<b>%s</b>''\n%b";
        alignment = "left";
        show_age_threshold = 60;
        word_wrap = true;
        ignore_newline = true;
        stack_duplicates = true;
        hide_duplicate_count = false;
        show_indicators = true;
        icon_position = "left";
        max_icon_size = 86;
        min_icon_size = 32;
        icon_theme = "Papirus";
        enable_recursive_icon_lookup = true;
        sticky_history = true;
        history_length = 20;
        browser = "firefox";
        always_run_script = true;
        title = "Dunst";
        class = "Dunst";
        corner_radius = 10;
        icon_corner_radius= 5;
        notification_limit = 5;
        mouse_left_click = "close_current";
        mouse_middle_click = "do_action";
        mouse_right_click = "context_all";
        ignore_dbusclose = true;
        ellipsize = "middle";
      };

      urgency_normal = {
        timeout = 6;
<<<<<<< HEAD
        # background = "#${config.colorScheme.palette.base00}";
        # frame_color = "#${config.colorScheme.palette.base07}";
        # foreground = "#${config.colorScheme.palette.base06}";
      };
      urgency_low = {
        timeout = 2;
        # background = "#${config.colorScheme.palette.base00}";
        # frame_color = "#${config.colorScheme.palette.base07}";
        # foreground = "#${config.colorScheme.palette.base06}";
      };
      urgency_critical = {
        timeout = 30;
        # background = "#${config.colorScheme.palette.base00}";
        # frame_color = "#${config.colorScheme.palette.base07}";
        # foreground = "#${config.colorScheme.palette.base06}";
=======
        background = "#${config.colorScheme.palette.base00}";
        frame_color = "#${config.colorScheme.palette.base07}";
        foreground = "#${config.colorScheme.palette.base06}";
      };
      urgency_low = {
        timeout = 2;
        background = "#${config.colorScheme.palette.base00}";
        frame_color = "#${config.colorScheme.palette.base07}";
        foreground = "#${config.colorScheme.palette.base06}";
      };
      urgency_critical = {
        timeout = 30;
        background = "#${config.colorScheme.palette.base00}";
        frame_color = "#${config.colorScheme.palette.base07}";
        foreground = "#${config.colorScheme.palette.base06}";
>>>>>>> 6f826e2188d86f7d0c76929d56e6cedb6863fd9d
      };
      fullscreen_show_critical = {
        msg_urgency = "critical";
        fullscreen = "pushback";
      };
      network = {
        appname = "network";
        new_icon = "network";
        summary = "*";
        format = "<span size='x-large' weight='bold'>%s</span>''\n<span font_desc='Cooper Hewitt,Iosevka Nerd Font 12'>%b</span>";
      };
      NetworkManager_Applet = {
        appname = "NetworkManager Applet";
        new_icon = "network-wireless";
      };
    };
  };
}
