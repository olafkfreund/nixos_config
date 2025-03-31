{...}: {
  programs.nixcord = {
    enable = true; # enable Nixcord. Also installs discord package
    quickCss = "./gruvb-dark.theme.css"; # path to your quickCSS file
    config = {
      useQuickCss = true; # use out quickCSS
      frameless = true; # set some Vencord options
      plugins = {
        hideAttachments.enable = true; # Enable a Vencord plugin
        blurNSFW.enable = true;
        fakeNitro.enable = true;
        fakeNitro.enableStickerBypass = true;
        customRPC.enable = true;
        betterSettings.enable = true;
        betterFolders.enable = true;
        # plainFolderIcons = true; # Enable another Vencord plugin
      };
    };
    extraConfig = {
    };
  };
}
