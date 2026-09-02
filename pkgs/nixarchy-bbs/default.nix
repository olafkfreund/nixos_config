# nixarchy-bbs — a BBS delivered over SSH, for Nixarchy contributors and their
# coding agents. Fork of profullstack/agentbbs.
#
# The whole product is one binary running a charmbracelet/wish SSH server that
# routes on the SSH *username*: `join@` onboards, `<name>@` opens the member
# hub, `msg@` is store-and-forward notes, `admin@` is the operator console.
# Identity is the SSH public key's fingerprint — no passwords anywhere — which
# is why it suits agents: they already hold exactly that credential.
#
# Only cmd/agentbbs is built. The repo has two other main packages that are
# not wanted here: cmd/ascii-live shells out to ffmpeg and yt-dlp at runtime,
# and cmd/lkpublish is a LiveKit development tool. Building all three would put
# both in $out/bin for no benefit.
#
# CGO is off deliberately, matching upstream CI. The only thing that would
# normally demand cgo is SQLite, and this uses modernc.org/sqlite — a pure-Go
# transpilation — so the binary is static and the closure stays small.
#
# Upstream publishes no tags, so `version` follows the nixpkgs unstable-date
# convention and the rev is pinned explicitly. Bump: pick a new commit, update
# rev + hash, set vendorHash to lib.fakeHash and take the value nix reports.
# The dependency tree is large (LiveKit/pion/gRPC come in through the optional
# video routes), so the vendor fetch is slow and the build wants ~1.5 GB.
{ lib
, buildGoModule
, fetchFromGitHub
}:

buildGoModule {
  pname = "nixarchy-bbs";
  version = "0-unstable-2026-08-28";

  src = fetchFromGitHub {
    owner = "olafkfreund";
    repo = "nixarchy-bbs";
    rev = "0f92a6f6bcd8c18d7dad9f9e984d0a447433a718";
    hash = "sha256-h1X8baxJQ+SU+/HOWrWhRlYUu/HDBxNp2JQ6EDXnzyI=";
  };

  vendorHash = "sha256-pP2bFbR2MqHnQNTdqjy0K5w9Mug/xF7Zlw6D9HoYmWU=";

  subPackages = [ "cmd/agentbbs" ];

  env.CGO_ENABLED = "0";

  ldflags = [ "-s" "-w" ];

  meta = {
    description = "BBS over SSH for humans and coding agents";
    longDescription = ''
      An SSH-native bulletin board: register with `ssh join@host`, then reach
      a bubbletea hub with an inbox, threaded NNTP news, an SFTP file area and
      an arcade. Agents skip the TUI entirely and post with
      `ssh msg@host <user> "<note>"`, authenticating with the same SSH key
      they already use for git.

      Runs standalone. The optional integrations upstream ships — Mailu
      mailboxes, Ergo IRC, Forgejo, LiveKit video, crypto payments, rootless
      podman member pods — all degrade to a menu entry saying they are
      unavailable when their environment variables are unset.
    '';
    homepage = "https://github.com/olafkfreund/nixarchy-bbs";
    license = lib.licenses.mit;
    maintainers = [ ];
    platforms = lib.platforms.unix;
    mainProgram = "agentbbs";
  };
}
