{ lib
, buildGoModule
, fetchFromGitHub
}:

buildGoModule rec {
  pname = "kosli-cli";
  version = "2.11.31";

  src = fetchFromGitHub {
    owner = "kosli-dev";
    repo = "cli";
    rev = "v${version}";
    hash = "sha256-nlMiTUPhR9S/exrWk95oWmrKTC/r2rxFFzWKMGFEVsU=";
  };

  # Vendor hash calculated from go.mod dependencies
  vendorHash = "sha256-81SVz4Vs+NVk013JlfEz99zKiJUhjSE2K3xCU+xJ0Qw=";

  # Enable strict dependency separation for cross-compilation
  strictDeps = true;

  # Embed version information into the binary
  # Based on upstream Makefile ldflags (excluding -static for Nix compatibility)
  ldflags = [
    "-s"
    "-w"
    "-X github.com/kosli-dev/cli/internal/version.version=${version}"
    "-X github.com/kosli-dev/cli/internal/version.gitCommit=v${version}"
    "-X github.com/kosli-dev/cli/internal/version.gitTreeState=clean"
  ];

  # Skip tests that may require network access or external services
  doCheck = false;

  meta = {
    description = "CLI client for reporting compliance events to kosli.com";
    longDescription = ''
      Kosli CLI is a command-line tool for recording and querying software
      delivery events at kosli.com. It enables teams to report compliance
      events to Kosli's service, supporting continuous compliance tracking
      and DevOps workflows.
    '';
    homepage = "https://github.com/kosli-dev/cli";
    changelog = "https://github.com/kosli-dev/cli/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "kosli";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
