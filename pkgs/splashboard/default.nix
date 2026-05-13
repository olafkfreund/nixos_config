{ lib
, fetchFromGitHub
, rustPlatform
, pkg-config
, git
}:
rustPlatform.buildRustPackage rec {
  pname = "splashboard";
  version = "1.6.0";

  src = fetchFromGitHub {
    owner = "unhappychoice";
    repo = "splashboard";
    rev = "v${version}";
    hash = "sha256-51ljQbuK5irrJXHg4ZO/VMgZmjKQZi+GwXcw1b4kY/A=";
  };

  cargoHash = "sha256-igWOT6/kl27BItfwIHnOfLdRTjKMEHdu24l9jA/2g8A=";

  strictDeps = true;

  nativeBuildInputs = [
    pkg-config
    git
  ];

  doCheck = false;

  meta = {
    description = "Customizable terminal splash screen with plugin-based data sources";
    longDescription = ''
      splashboard renders a TUI dashboard at shell startup and on cd into a
      directory. Built on ratatui + crossterm, pure-Rust git (gix) and rustls
      (no OpenSSL). Per-repo overrides live at ./.splashboard/dashboard.toml
      with a trust.toml allow-list. Config lives at $HOME/.splashboard/
      (override via SPLASHBOARD_HOME). Opt-out env vars: CI, SPLASHBOARD_SILENT,
      NO_SPLASHBOARD.
    '';
    homepage = "https://github.com/unhappychoice/splashboard";
    changelog = "https://github.com/unhappychoice/splashboard/releases/tag/v${version}";
    license = lib.licenses.isc;
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.linux;
    mainProgram = "splashboard";
  };
}
