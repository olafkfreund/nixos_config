{ inputs
, pkgs
, ...
}: {
  home.packages = with inputs.browser-previews.packages.${pkgs.system}; [
    # (google-chrome-beta.override {
    #   commandLineArgs =[
    #     "--enable-features=UseOzonePlatform"
    #     "--ozone-platform=wayland"
    #     ];
    #   })
    google-chrome-beta
  ];
}

