{
  programs.zathura = {
    enable = true;
    extraConfig = ''
      set font JetBrainsMono
      set font 10

      map D set "first-page-column 1:1"
      map <C-d> set "first-page-column 1:2"

      set selection-clipboard clipboard

      set notification-error-bg       "#1d2021" # bg
      set notification-error-fg       "#fb4934" # bright:red
      set notification-warning-bg     "#1d2021" # bg
      set notification-warning-fg     "#fabd2f" # bright:yellow
      set notification-bg             "#1d2021" # bg
      set notification-fg             "#b8bb26" # bright:green

      set completion-bg               "#504945" # bg2
      set completion-fg               "#ebdbb2" # fg
      set completion-group-bg         "#3c3836" # bg1
      set completion-group-fg         "#928374" # gray
      set completion-highlight-bg     "#83a598" # bright:blue
      set completion-highlight-fg     "#504945" # bg2

      # Define the color in index mode
      set index-bg                    "#504945" # bg2
      set index-fg                    "#ebdbb2" # fg
      set index-active-bg             "#83a598" # bright:blue
      set index-active-fg             "#504945" # bg2

      set inputbar-bg                 "#1d2021" # bg
      set inputbar-fg                 "#ebdbb2" # fg

      set statusbar-bg                "#504945" # bg2
      set statusbar-fg                "#ebdbb2" # fg

      set highlight-color             "#fabd2f" # bright:yellow
      set highlight-active-color      "#fe8019" # bright:orange

      set default-bg                  "#1d2021" # bg
      set default-fg                  "#ebdbb2" # fg
      set render-loading              true
      set render-loading-bg           "#1d2021" # bg
      set render-loading-fg           "#ebdbb2" # fg

      # Recolor book content's color
      set recolor-lightcolor          "#1d2021" # bg
      set recolor-darkcolor           "#ebdbb2" # fg
      set recolor                     "true"
      # set recolor-keephue             true      # keep original color's hue
    '';
  };
}