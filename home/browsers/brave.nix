{ pkgs, ...}: {
  home.packages = with pkgs; [
    brave # Brave browser
    opera # Opera browser
    ungoogled-chromium # Ungoogled Chromium browser

  ];
}
