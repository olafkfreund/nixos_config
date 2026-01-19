{ lib
, stdenv
, rustPlatform
, fetchFromGitHub
, just
, pkg-config
, libcosmicAppHook
, libxkbcommon
, openssl
, gtk3
, webkitgtk_4_1
, nix-update-script
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "quick-webapps";
  version = "2.0.1";

  src = fetchFromGitHub {
    owner = "cosmic-utils";
    repo = "web-apps";
    tag = "2.0.1";
    hash = "sha256-vWEa6mSK8lhqHRU/Zgi2HUGIs37G7E28AEEWj7TSaPc=";
  };

  cargoHash = "sha256-bwoG4KMB8JQHE+dc3X2OHDDmg1jWBfXMcR68bbCq/Ag=";

  nativeBuildInputs = [
    just
    pkg-config
    libcosmicAppHook
  ];

  buildInputs = [
    libxkbcommon
    openssl
    gtk3
    webkitgtk_4_1
  ];

  env.VERGEN_GIT_SHA = finalAttrs.src.tag;

  dontUseJustBuild = true;
  dontUseJustCheck = true;

  preInstall = ''
    mkdir -p target/release
    ln -s ../${stdenv.hostPlatform.rust.cargoShortTarget}/release/dev-heppen-webapps-webview target/release/
  '';

  justFlags = [
    "--set"
    "prefix"
    (placeholder "out")
    "--set"
    "bin-src"
    "target/${stdenv.hostPlatform.rust.cargoShortTarget}/release/dev-heppen-webapps"
  ];

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Web App Manager for the COSMIC desktop";
    homepage = "https://github.com/cosmic-utils/web-apps";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ pluiedev ];
    mainProgram = "dev.heppen.webapps";
  };
})
