{ pkgs, config, libs, ... }: {

    programs.fzf = {
        enable = true;
        enableBashIntegration = false;
        colors = {
            fg = "#ebdbb2";
            bg = "#282828";
            hl = "#fabd2f";
            "fg+" = "#ebdbb2";
            "bg+" = "#3c3836";
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