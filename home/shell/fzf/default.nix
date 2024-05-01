{ pkgs, config, libs, ... }: {

    programs.fzf = {
        enable = true;
        enableBashIntegration = false;
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