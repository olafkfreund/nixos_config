# obsidian-cli — vault operations that plain file tools cannot do safely.
#
# Reading, writing and editing notes needs no tool: an Obsidian vault is a
# directory of Markdown files. What this provides is the part that is genuinely
# hard from the outside — `move` is documented upstream as "Move or rename note
# in vault and updated corresponding links", i.e. it rewrites every [[wikilink]],
# heading link and block reference pointing at the note. Doing that with
# grep+sed across ~2950 notes silently corrupts aliases and block refs.
#
# NOTE ON NAMING: the repo is still Yakitrak/obsidian-cli, but the Go module and
# the installed binary were renamed to `notesmd-cli`. mainProgram reflects the
# binary, not the repo. Neither name exists in nixpkgs as of 2026-07.
#
# Bump: check `gh release view --repo Yakitrak/obsidian-cli`, update version +
# hash, then set vendorHash to lib.fakeHash and take the value nix reports.
{ lib
, buildGoModule
, fetchFromGitHub
}:

buildGoModule rec {
  pname = "obsidian-cli";
  version = "0.3.6";

  src = fetchFromGitHub {
    owner = "Yakitrak";
    repo = "obsidian-cli";
    rev = "v${version}";
    hash = "sha256-TubUNSpLvv3Q8dixeCf7otG6CSlb8haIGqkMFXAsqYI=";
  };

  vendorHash = null;

  # Upstream tests shell out to a real vault and an $EDITOR; they are not
  # hermetic and fail in the sandbox.
  doCheck = false;

  ldflags = [
    "-s"
    "-w"
    "-X=github.com/Yakitrak/notesmd-cli/cmd.version=${version}"
  ];

  # Short alias. Deliberately `ob`, NOT `obs`: obs is OBS Studio's launcher
  # (pkgs.obs-studio, enabled here via home/desktop/obs) and shadowing it would
  # break screen recording. `obsidian-cli` is likewise unavailable — that name
  # is already taken by the CLI bundled inside pkgs.obsidian, which is a
  # different tool entirely (it drives the running desktop app and currently
  # fails on NixOS with "unable to find Obsidian").
  #
  # A symlink rather than a shell alias so it also resolves from scripts,
  # non-interactive shells and the `obsidian` Claude Code skill.
  postInstall = ''
    ln -s notesmd-cli $out/bin/ob
  '';

  meta = {
    description = "Interact with Obsidian vaults from the terminal";
    longDescription = ''
      CLI for Obsidian vaults. The operations worth having over plain file
      access are link-aware: `move` renames a note and rewrites every link that
      referenced it, `search-content` searches note bodies, `frontmatter` reads
      and writes YAML properties, and `daily` resolves periodic notes.

      Installed as `notesmd-cli` — upstream renamed the binary while keeping
      the repository name.
    '';
    homepage = "https://github.com/Yakitrak/obsidian-cli";
    license = lib.licenses.mit;
    maintainers = [ ];
    platforms = lib.platforms.unix;
    mainProgram = "notesmd-cli";
  };
}
