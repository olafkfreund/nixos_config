{ config, ... }: {

    programs.fzf = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        defaultOptions = [
         "--preview 'fzf-preview {}' 
          --preview-window '50%:hidden' 
          --height 40%
          --bind 'ctrl-/:toggle-preview'
          --bind 'enter:become(lvim {+})'
          --layout reverse 
          --info inline 
          --border 
          --color 'border:#fe8019'" 
        ];
        defaultCommand = "fd --type f";
        fileWidgetCommand = "fd --type f";
        changeDirWidgetCommand = "fd --type f";
        changeDirWidgetOptions = [
          "--preview 'fzf-preview {}' 
          --preview-window '50%:hidden' 
          --height 40%
          --bind 'ctrl-/:toggle-preview'
          --bind 'enter:become(lvim {+})'
          --layout reverse 
          --info inline 
          --border 
          --color 'border:#fe8019'"];
        colors = {
            fg = "#${config.colorScheme.palette.base05}";
            bg = "#${config.colorScheme.palette.base00}";
            hl = "#${config.colorScheme.palette.base0A}";
            "fg+" = "#${config.colorScheme.palette.base05}";
            "bg+" = "#${config.colorScheme.palette.base00}";
            "hl+" = "#${config.colorScheme.palette.base0A}";
            info = "#${config.colorScheme.palette.base0C}";
            prompt = "#${config.colorScheme.palette.base0D}";
            spinner = "#${config.colorScheme.palette.base05}";
            pointer = "#${config.colorScheme.palette.base0C}";
            marker = "#${config.colorScheme.palette.base0E}";
            header = "#${config.colorScheme.palette.base04}";
            border = "#${config.colorScheme.palette.base09}";
        };
    };
}
