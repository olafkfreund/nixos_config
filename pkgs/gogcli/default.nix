{ lib
, buildGoModule
, fetchFromGitHub
,
}:

# gogcli — "Google Workspace in your terminal" (gmail, calendar, tasks,
# contacts, drive). Binary is `gog`.
#
# We track the canonical openclaw repo ourselves rather than taking nixpkgs'
# gogcli. Note the original reason for that is GONE: the header used to say
# nixpkgs shipped 0.11.0 under the old `steipete` owner and therefore lacked
# the auth tokens export/import + service-account surface we need to provision
# the OAuth token onto headless p510 via agenix. As of 2026-09 nixpkgs is on
# 0.38.1 from the openclaw lineage and has all of it. What keeps this local is
# now only release latency — upstream ships every few days, and the nightly
# bump in .github/workflows/package-autoupdate.yml follows it within a day.
# If that stops being worth a hand-maintained vendorHash, delete this and use
# pkgs.gogcli.
#
# The Go module path is still `github.com/steipete/gogcli`, so the version
# ldflags target that path even though the source lives at openclaw.
#
# Bumping this does NOT update every gog on the machine. gogmail is a flake
# input with its own locked nixpkgs (flake.nix says no follows, on purpose, so
# its tested Python closure builds as released) and it bakes its own gogcli into
# its wrapper PATH -- which is why a built host closure contains two gogcli
# versions at once. `nix why-depends <system> <old-gogcli>` names gogmail as the
# holder. That is intended, not drift: the TUI is tested against its pin. Only
# the `gog` on PATH, the gog-dashboard timer and the agenix token import use
# this derivation.
buildGoModule (finalAttrs: {
  pname = "gogcli";
  version = "0.40.0";

  src = fetchFromGitHub {
    owner = "openclaw";
    repo = "gogcli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-JAIN0MaQegHkg1zBsIYf2YIh3VyeFvQdvyXe9U9AZjg=";
  };

  vendorHash = "sha256-6+/8FVPtrRdE1Hn/MkneZWUiOD/fnQkGYG/T/KD8Du8=";

  subPackages = [ "cmd/gog" ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/steipete/gogcli/internal/cmd.version=v${finalAttrs.version}"
    "-X github.com/steipete/gogcli/internal/cmd.commit=${finalAttrs.src.rev}"
    "-X github.com/steipete/gogcli/internal/cmd.date=1970-01-01T00:00:00Z"
  ];

  passthru.updateScript = ../../scripts/update-gogcli.sh;

  meta = {
    description = "Google Workspace in your terminal (Gmail, Calendar, Tasks, Contacts, Drive)";
    homepage = "https://gogcli.sh";
    changelog = "https://github.com/openclaw/gogcli/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "gog";
    platforms = lib.platforms.unix;
  };
})
