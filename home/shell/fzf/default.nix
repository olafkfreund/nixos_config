{ pkgs, config, lib, ... }: {

    programs.fzf = {
        enable = true;
        enableBashIntegration = true;
        defaultOptions = [ "--height 33%" "--no-separator" "--reverse" ];
        defaultCommand = "fd --no-ignore-parent --one-file-system --type file";
        #fileWidgetCommand = defaultCommand;
        changeDirWidgetCommand = "fd --no-ignore-parent --one-file-system --type directory";
        colors = {
            fg = "#${config.colorScheme.palette.base05}";
            bg = "#${config.colorScheme.palette.base00}";
            hl = "#fabd2f";
            "fg+" = "#${config.colorScheme.palette.base05}";
            "bg+" = "#${config.colorScheme.palette.base00}";
            "hl+" = "#fabd2f";
            info = "#83a598";
            prompt = "#bdae93";
            spinner = "#fabd2f";
            pointer = "#83a598";
            marker = "#fe8019";
            header = "#665c54";
        };
    };
}
