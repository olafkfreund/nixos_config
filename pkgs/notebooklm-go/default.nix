# notebooklm-go — CLI for Google NotebookLM's internal batchexecute RPC.
#
# Reverse-engineered, unofficial, and the upstream README says so in three
# separate places. Worth restating here because it changes how this should be
# treated: the RPC method IDs come from Google's frontend bundle and can change
# without notice, so this breaks on Google's schedule, not ours. Upstream's own
# advice is to pin a release tag rather than track master, which is what the
# `version` below does. Not in nixpkgs as of 2026-09.
#
# Authentication is your live Google session cookie, stored by the tool at
# ~/.config/notebooklm-go/auth.json with 0600 perms. Nothing here declares it
# and nothing should: it is created interactively by `notebooklm login`, it
# rotates when Google rotates it, and it is a user credential rather than a
# system secret -- so agenix is the wrong instrument. Two things follow.
# First, the cookie carries the full power of the account, deletion included,
# so a dedicated Google account is the cautious choice. Second, that path is
# deliberately outside the syncthing folders in modules/services/syncthing.nix
# (which cover ~/.claude and ~/.gemini only), so the credential does not
# replicate to other hosts. Keep it that way.
#
# Bump: check `gh release view --repo LocalKinAI/notebooklm-go`, update version
# + hash, then set vendorHash to lib.fakeHash and take the value nix reports.
{ lib
, buildGoModule
, fetchFromGitHub
, makeWrapper
, google-chrome
}:

buildGoModule rec {
  pname = "notebooklm-go";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "LocalKinAI";
    repo = "notebooklm-go";
    rev = "v${version}";
    hash = "sha256-6U+iV0lF7nmHRzvPV7VgBY92gFMky+LQUnlOwzWtcVU=";
  };

  vendorHash = "sha256-xPoa/axatOR5v1oPwDZVo6r7SnFqehLI2zSm6EyIfkk=";

  # The repo is a library first; cmd/notebooklm is the CLI. Building only that
  # keeps examples/ (three more main packages, one per demo) out of $out/bin,
  # where they would otherwise land as `list_notebooks` and friends and
  # collide with anything else claiming those very generic names.
  subPackages = [ "cmd/notebooklm" ];

  nativeBuildInputs = [ makeWrapper ];

  ldflags = [ "-s" "-w" ];

  # Put a browser on PATH for `notebooklm login`.
  #
  # The data path is pure HTTPS -- chromedp appears in exactly one file,
  # login.go, and only for the optional interactive OAuth flow. That flow calls
  # chromedp.NewExecAllocator without an ExecPath override, so chromedp falls
  # back to searching PATH for a Chrome binary and fails with an unhelpful
  # allocator error when it finds none. Wrapping is therefore about `login`
  # alone: every other subcommand ignores this entirely, and the cookie-paste
  # flow needs no browser at all.
  #
  # google-chrome rather than chromium because it is what this configuration
  # already installs and sets as the default handler (home/desktop/com.nix), so
  # the browser that opens is the one already signed in to Google -- which is
  # the entire point of the flow.
  postInstall = ''
    wrapProgram $out/bin/notebooklm \
      --prefix PATH : ${lib.makeBinPath [ google-chrome ]}
  '';

  meta = {
    description = "Unofficial CLI and Go client for Google NotebookLM";
    longDescription = ''
      Drives NotebookLM from the shell: list and create notebooks, add PDF, URL
      and text sources, trigger Audio Overviews, Mind Maps, Reports, Slide
      Decks and Deep Research, and download the generated artifacts.

      Talks to the same `batchexecute` endpoint the official web bundle uses,
      authenticating with your own Google session cookie. Reverse-engineered
      and unaffiliated with Google: expect it to break when the frontend
      bundle changes, and prefer an account you can afford to lose.
    '';
    homepage = "https://github.com/LocalKinAI/notebooklm-go";
    license = lib.licenses.asl20;
    maintainers = [ ];
    platforms = lib.platforms.unix;
    mainProgram = "notebooklm";
  };
}
