{ inputs
, pkgs
, ...
}: {
  home.packages = with inputs.browser-previews.packages.${pkgs.system}; [
    # (google-chrome-dev.override {
    #   commandLineArgs =[
    #     "--enable-features=UseOzonePlatform"
    #     "--ozone-platform=wayland"
    #     ];
    #   })
     google-chrome-dev
  ];
}

