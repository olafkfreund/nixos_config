{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, openssl
, sqlite
}:
rustPlatform.buildRustPackage rec {
  pname = "reddix";
  version = "0.2.9";

  src = fetchFromGitHub {
    owner = "ck-zhang";
    repo = "reddix";
    rev = "v${version}";
    hash = "sha256-4MKRzqsTJxtiAGCvQdAAIMbAcXKwkIth1g1uvQuGXso=";
  };

  cargoHash = "sha256-4R27KeXu7nRA7A7GLbhIf+j5RKnOrOoysoUcZH053ns=";

  doCheck = false; # Upstream test failure: config::tests::load_defaults_without_files

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    openssl
    sqlite
  ];

  meta = with lib; {
    description = "A Reddit TUI client written in Rust";
    homepage = "https://github.com/ck-zhang/reddix";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.linux;
    mainProgram = "reddix";
  };
}
