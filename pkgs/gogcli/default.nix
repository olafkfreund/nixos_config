{ lib
, buildGoModule
, fetchFromGitHub
,
}:

# gogcli — "Google Workspace in your terminal" (gmail, calendar, tasks,
# contacts, drive). Binary is `gog`. nixpkgs ships an older 0.11.0 under the
# original `steipete` owner; we track the canonical openclaw repo at the
# latest tag so the auth tokens export/import + service-account surface is
# available (needed to provision the OAuth token onto the headless p510 via
# agenix). The Go module path is still `github.com/steipete/gogcli`, so the
# version ldflags target that path even though the source lives at openclaw.
buildGoModule (finalAttrs: {
  pname = "gogcli";
  version = "0.19.0";

  src = fetchFromGitHub {
    owner = "openclaw";
    repo = "gogcli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-8+ojZUNsmAzFQbdTG0eE/FG6nbptq49QZqjrCP1RhE4=";
  };

  vendorHash = "sha256-fkvMTJmYRsknDDffrZq2L2GRYDozwPX0yv7K84n5a84=";

  subPackages = [ "cmd/gog" ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/steipete/gogcli/internal/cmd.version=v${finalAttrs.version}"
    "-X github.com/steipete/gogcli/internal/cmd.commit=${finalAttrs.src.rev}"
    "-X github.com/steipete/gogcli/internal/cmd.date=1970-01-01T00:00:00Z"
  ];

  meta = {
    description = "Google Workspace in your terminal (Gmail, Calendar, Tasks, Contacts, Drive)";
    homepage = "https://gogcli.sh";
    changelog = "https://github.com/openclaw/gogcli/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "gog";
    platforms = lib.platforms.unix;
  };
})
