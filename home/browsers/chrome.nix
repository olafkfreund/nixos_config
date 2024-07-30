{pkgs, inputs, ...}: {
  home.packages = with inputs.browser-previews.packages.${pkgs.system}; [
    # (google-chrome.override {
    # commandLineArgs = [
    #   "--enable-features=UseOzonePlatform"
    #   "--ozone-platform=wayland"
    # ];
    # })
    # (chromium.override {
    # commandLineArgs = [
    #   "--enable-features=UseOzonePlatform"
    #   "--ozone-platform=wayland"
    # ];
    # })
    google-chrome
  ];
}
