{ config, ... }: {

    programs.fzf = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        defaultOptions = ["--height 40% --layout reverse --info inline --border --color 'border:#fe8019'" ];
        defaultCommand = "fd --type f";
        fileWidgetCommand = "fd --type f";
        changeDirWidgetCommand = "fd --type f";
        changeDirWidgetOptions = ["--preview 'bat --color=always {}' --preview-window '~3' --height 40% --layout reverse --info inline --border --color 'border:#fe8019'"];
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
