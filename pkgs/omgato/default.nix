{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, systemdLibs
}:
# Omgato: CLI daemons behind the Omgato Omarchy bar plugin (Stream Deck, Key
# Lights, Cam Link). The plugin itself is managed by `omarchy plugin`; this
# package only provides the binaries it calls by name on PATH.
#
# Bump together with the plugin (its manifest.json version) so the widget
# never calls a subcommand this build lacks. Do not run upstream's
# scripts/install: Home Manager owns the systemd user units (#1978).
rustPlatform.buildRustPackage rec {
  pname = "omgato";
  version = "0.1.7";

  src = fetchFromGitHub {
    owner = "data-goblin";
    repo = "omgato";
    tag = "v${version}";
    hash = "sha256-uYBJQMNUjbtUxSj/evfkfoLCw3+gjLgUFs+s8dbEcrY=";
  };

  cargoHash = "sha256-KarTFFyhD6PfA6XtHEwVmew7kqHbn5qoSxQPYzehhV0=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ systemdLibs ];

  postInstall = ''
    install -Dm0644 src/streamdeck-ctl/udev/70-streamdeck-ctl.rules -t $out/lib/udev/rules.d
  '';

  meta = {
    description = "Stream Deck, Key Light and Cam Link control for Omarchy";
    homepage = "https://github.com/data-goblin/omgato";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "streamdeck-ctl";
  };
}
