{...}: {
  wayland.windowManager.hyprland.extraConfig = ''
    #Terminal rules
    windowrulev2 = float, class:(alacritty)
    windowrulev2 = size 1000 1000, class:(alacritty)
    windowrulev2 = float, class:(kitty)
    windowrulev2 = size 1000 1000, class:(kitty)
    windowrulev2 = float, class:(wezterm)
    windowrulev2 = size 1000 1000, class:(wezterm)
    windowrulev2 = float, class:(foot)
    windowrulev2 = size 1000 1000, class:(foot)
    windowrule = animation slide left, class:^(foot)$


    # Window rules #
    windowrule = workspace current,title:MainPicker
    windowrule = workspace current,.blueman-manager-wrapped
    windowrule = workspace current,xdg-desktop-portal-gtk

    # Rofi
    # windowrulev2 = forceinput, class:(Rofi)$
    windowrule = animation bounce, ^(rofi)$

    # Obsidian
    windowrulev2 = float, class:(obsidian)

    #Slack
    windowrulev2 = workspace special:slack, float, class:^(Slack)
    windowrulev2 = workspace special:slack,size 50% 50%,float,class:^(Slack),tilte:^(Huddle)

    #Tmux
    windowrulev2 = workspace special:tmux, float, title:^(tmux-sratch)

    #Spotify
    windowrulev2 = workspace special:spotify, float, class:^(spotify)

    #thunderbird
    windowrulev2 = workspace special:mail, class:^(thunderbird)$
    windowrule = animation slide left, ^(thunderbird)$
    windowrulev2 = size 70% 70%,float,class:(thunderbird)$
    windowrulev2 = size 70% 70%,float,class:^(thunderbird)$,title:^(.*)(Reminder)(.*)$
    windowrulev2 = float,class:^(thunderbird)$,title:^(.*)(Write)(.*)$

    #Google Chrome
    windowrulev2 = workspace 2, float, class:(google-chrome)
    windowrulev2 = workspace special:spotify, class:^(Spotify)$
    windowrulev2 = float,size 900 500,title:^(Choose Files)
    windowrulev2 = float,size 900 500,title:^(Sign in)
    windowrulev2 = workspace 4, class:^(Edge)$

    #Pavucontrol
    windowrulev2 = float, class:(pavucontrol)
    windowrulev2 = size 1000 1000, class:(pavucontrol)
    windowrulev2 = center, class:(pavucontrol)

    #Moonlight
    windowrulev2 = size 50% 50%, float, class:(com.moonlight_stream.Moonlight)

    #Camera
    windowrulev2 = size 500 500, fload, class:(hu.irl.cameractrls)

    #Zen
    windowrulev2 = size 70% 70%, float, class:(zen.aplha)$,title:^(.*)(Save)(.*)$

    #Telegram
    windowrulev2 = workspace 8, class:(org.telegram.desktop)
    windowrulev2 = size 970 480, class:(org.telegram.desktop), title:(Choose Files)
    windowrulev2 = center, class:(org.telegram.desktop), title:(Choose Files)

    #Gnome
    windowrulev2 = float, class:(org.gnome.*)
    windowrulev2 = size 1000 1000, class:(org.gnome.*)
    windowrulev2 = center, class:(org.gnome.*)
    windowrule = animation slide up`, ^(org.gnome.Calendar)$
    windowrule = size 400 500,^(org.gnome.Calendar)$
    windowrulev2 = move 480 45, class:^(org.gnome.Calendar)$

    windowrulev2 = float, class:(blueman-manager)
    windowrulev2 = center, class:(blueman-manager)
    windowrulev2 = float,class:^(nm-applet)$
    windowrulev2 = float,class:^(nm-connection-editor)$

    # Allow screen tearing for reduced input latency on some games.
    windowrulev2 = immediate, class:^(cs2)$
    windowrulev2 = immediate, class:^(steam_app_0)$
    windowrulev2 = immediate, class:^(steam_app_1)$
    windowrulev2 = immediate, class:^(steam_app_2)$
    windowrulev2 = immediate, class:^(.*)(.exe)$
    windowrulev2 = float, class:(xdg-desktop-portal-gtk)
    windowrulev2 = size 1345 720, class:(xdg-desktop-portal-gtk)
    windowrulev2 = center, class:(xdg-desktop-portal-gtk)

    #Xwayland hack
    windowrulev2 = opacity 0.0 override,class:^(xwaylandvideobridge)$
    windowrulev2 = noanim,class:^(xwaylandvideobridge)$
    windowrulev2 = noinitialfocus,class:^(xwaylandvideobridge)$
    windowrulev2 = maxsize 1 1,class:^(xwaylandvideobridge)$
    windowrulev2 = noblur,class:^(xwaylandvideobridge)$

    # Xdg
    windowrulev2 = float, class:^(xdg-desktop-portal-gtk)$
    windowrulev2 = size 900 500, class:^(xdg-desktop-portal-gtk)$
    windowrulev2 = dimaround, class:^(xdg-desktop-portal-gtk)$
    windowrulev2 = center, class:^(xdg-desktop-portal-gtk)$
  '';
}
