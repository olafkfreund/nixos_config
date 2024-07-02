{...}: {
  programs.google-chrome = {
    enable = true;
    commandLineArgs = [
      "--enable-features=UseOzonePlatform"
      "--ozone-platform=wayland"
      "--ozone-platform-hint=auto"
    ];
  };
}
