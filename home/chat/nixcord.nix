{...}: {
  programs.nixcord = {
    enable = true; # enable Nixcord. Also installs discord package
    quickCss = "./gruvb-dark.theme.css"; # path to your quickCSS file
    config = {
      useQuickCss = true; # use out quickCSS
      # themeLinks = [
      #   "https://refact0r.github.io/system24/theme/gruvbox-material.theme.css"
      # ];
      frameless = true; # set some Vencord options
      plugins = {
        hideAttachments.enable = true; # Enable a Vencord plugin
        blurNSFW.enable = true;
        plainFolderIcons = true; # Enable another Vencord plugin
      };
    };
    extraConfig = {
    };
  };
}
