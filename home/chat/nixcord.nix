{
  ...
}: {
  programs.nixcord = {
    enable = true; # enable Nixcord. Also installs discord package
    config = {
      useQuickCss = false; # use out quickCSS
      themeLinks = [
        "https://refact0r.github.io/system24/theme/gruvbox-material.theme.css"
      ];
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
