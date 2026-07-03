{ lib
, rustPlatform
, fetchFromGitHub
, makeWrapper
, glab
, git
}:
# A terminal UI for GitLab built on top of the `glab` CLI. Browse issues,
# merge requests, pipelines, runners and releases without leaving the terminal.
# Upstream ships no LICENSE ("built for personal use") — treated as unfree.
rustPlatform.buildRustPackage rec {
  pname = "glab-tui";
  version = "2.3.0";

  src = fetchFromGitHub {
    owner = "rcieri";
    repo = "glab-tui";
    rev = "v${version}";
    hash = "sha256-CsLcOIosfx7BVWXlhknKHNZVMVi0OWJ77ohDn73of1s=";
  };

  cargoHash = "sha256-SFihRea0X0IIfBnfwVoFfptQCQEmLZU/ik46GK5q8+c=";

  nativeBuildInputs = [ makeWrapper ];

  # glab-tui shells out to the `glab` CLI (and git) at runtime; put them on PATH.
  postInstall = ''
    wrapProgram $out/bin/glab-tui \
      --prefix PATH : ${lib.makeBinPath [ glab git ]}
  '';

  meta = {
    description = "Terminal UI for GitLab built on top of glab (issues, MRs, pipelines, runners, releases)";
    homepage = "https://github.com/rcieri/glab-tui";
    license = lib.licenses.unfree;
    maintainers = [ ];
    platforms = lib.platforms.linux;
    mainProgram = "glab-tui";
  };
}
