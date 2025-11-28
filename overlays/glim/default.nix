{ lib
, fetchFromGitHub
, rustPlatform
, pkg-config
, openssl
}:

rustPlatform.buildRustPackage rec {
  pname = "glim";
  version = "0.2.1";

  src = fetchFromGitHub {
    owner = "junkdog";
    repo = "glim";
    rev = "glim-v${version}";
    hash = "sha256-m5ZHXEu06kyCGqHBvcBgdgbi6gjHtegWrE1tDnMHyFg=";
  };

  cargoHash = "sha256-4NJtGqKOUWyv1ZcrQqqZgGI8vzSZpRfcVJWI7TKZCi8=";

  # Enable strict dependency separation for cross-compilation
  strictDeps = true;

  # Build-time dependencies (tools that run on build platform)
  nativeBuildInputs = [
    pkg-config
  ];

  # Runtime dependencies (libraries linked into binary)
  buildInputs = [
    openssl
  ];

  meta = with lib; {
    description = "Terminal user interface for GitLab CI/CD pipeline monitoring";
    longDescription = ''
      glim is a TUI application for monitoring GitLab CI/CD pipelines and projects.
      Requires a GitLab personal access token with read_api scope and a terminal
      emulator with 24-bit color support.
    '';
    homepage = "https://github.com/junkdog/glim";
    changelog = "https://github.com/junkdog/glim/releases/tag/v${version}";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
    mainProgram = "glim";
  };
}
