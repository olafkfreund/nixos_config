# audible-sync — download + decrypt your Audible library to local .m4b files.
#
# UX: one command, `audible-sync`, after a one-time interactive login.
# Pipeline: library export → bulk download (.aaxc/.aax) → decrypt to .m4b
# → organise into one folder per book under `outputDir`. Re-runnable;
# already-downloaded books and already-decrypted files are skipped.
#
# Per-host wiring (currently p620 only):
#
#   features.audibleSync = {
#     enable = true;
#     outputDir = "~/audiobooks/audible";  # default
#   };
#
# One-time setup (run interactively on p620 AFTER deploy):
#   1. audible quickstart      # picks marketplace, handles 2FA in browser
#   2. audible library list    # confirm your books are visible
#   3. audible-sync            # downloads + decrypts everything
#
# Legal note: stripping DRM violates Audible's ToS. Personal-use only.
{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.features.audibleSync;

  audibleSync = pkgs.writeShellApplication {
    name = "audible-sync";
    # SC2088 (tilde in single quotes won't expand) is a false positive here —
    # `lib.escapeShellArg` below emits `'~/...'`, and the very next line uses
    # bash parameter expansion to substitute `~` with `$HOME` at runtime.
    excludeShellChecks = [ "SC2088" ];
    runtimeInputs = with pkgs; [
      audible-cli
      ffmpeg
      jq
      coreutils
      findutils
    ];
    text = ''
            set -euo pipefail

            OUTPUT_DIR=${lib.escapeShellArg cfg.outputDir}
            OUTPUT_DIR="''${OUTPUT_DIR/#\~/$HOME}"
            STAGING_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/audible-sync/staging"

            mkdir -p "$OUTPUT_DIR" "$STAGING_DIR"

            echo "==> Checking audible-cli login state..."
            # Fail loud (no stdin) so a missing login is obvious on first run.
            if ! audible profile list </dev/null >/dev/null 2>&1; then
              cat >&2 <<'EOF'
      audible-cli is not logged in.

      One-time setup (run interactively on this host):
        $ audible quickstart        # picks marketplace, handles 2FA in a browser
        $ audible library list      # confirm your books are visible
      Then re-run: audible-sync
      EOF
              exit 1
            fi

            echo "==> Fetching activation bytes (for legacy .aax decryption)..."
            ACTIVATION_BYTES="$(audible activation-bytes 2>/dev/null || true)"

            echo "==> Bulk download into $STAGING_DIR"
            # --ignore-existing makes this safe to re-run. </dev/null fails loud
            # if a future audible-cli version starts prompting.
            audible download \
              --all \
              --output-dir "$STAGING_DIR" \
              --aax-fallback \
              --quality best \
              --cover \
              --chapter \
              --ignore-existing \
              </dev/null

            echo "==> Decrypting .aaxc files..."
            decrypted=0; skipped=0; failed=0
            while IFS= read -r -d "" aaxc; do
              base="''${aaxc%.aaxc}"
              m4b="$base.m4b"
              voucher="$base.voucher"
              if [ -e "$m4b" ]; then
                skipped=$((skipped+1)); continue
              fi
              if [ ! -f "$voucher" ]; then
                echo "  [skip] no voucher for $(basename "$aaxc")" >&2
                failed=$((failed+1)); continue
              fi
              key=$(jq -r '.content_license.license_response.key // empty' "$voucher")
              iv=$(jq -r '.content_license.license_response.iv  // empty' "$voucher")
              if [ -z "$key" ] || [ -z "$iv" ]; then
                echo "  [skip] no key/iv in $(basename "$voucher") — voucher schema may have changed" >&2
                failed=$((failed+1)); continue
              fi
              echo "  [decrypt aaxc] $(basename "$aaxc")"
              ffmpeg -nostdin -hide_banner -loglevel error -y \
                -audible_key "$key" -audible_iv "$iv" \
                -i "$aaxc" -c copy "$m4b"
              decrypted=$((decrypted+1))
            done < <(find "$STAGING_DIR" -type f -name '*.aaxc' -print0)

            echo "==> Decrypting .aax files (legacy)..."
            while IFS= read -r -d "" aax; do
              base="''${aax%.aax}"
              m4b="$base.m4b"
              if [ -e "$m4b" ]; then
                skipped=$((skipped+1)); continue
              fi
              if [ -z "$ACTIVATION_BYTES" ]; then
                echo "  [skip] no activation bytes (run: audible activation-bytes)" >&2
                failed=$((failed+1)); continue
              fi
              echo "  [decrypt aax]  $(basename "$aax")"
              ffmpeg -nostdin -hide_banner -loglevel error -y \
                -activation_bytes "$ACTIVATION_BYTES" \
                -i "$aax" -c copy "$m4b"
              decrypted=$((decrypted+1))
            done < <(find "$STAGING_DIR" -type f -name '*.aax' -print0)

            echo "==> Organising into $OUTPUT_DIR/<book>/ ..."
            # audible-cli writes "<Author> - <Title>.<ext>" flat in the staging
            # dir. We copy the .m4b plus its cover/chapter sidecar into one
            # folder per book — Audiobookshelf's preferred layout.
            organised=0
            while IFS= read -r -d "" m4b; do
              dir="$(dirname "$m4b")"
              base="$(basename "$m4b" .m4b)"
              target="$OUTPUT_DIR/$base"
              if [ -e "$target/$base.m4b" ]; then continue; fi
              mkdir -p "$target"
              cp -n "$m4b" "$target/$base.m4b"
              for ext in jpg jpeg png chapters.json; do
                src="$dir/$base.$ext"
                [ -e "$src" ] && cp -n "$src" "$target/" || true
              done
              organised=$((organised+1))
            done < <(find "$STAGING_DIR" -maxdepth 1 -type f -name '*.m4b' -print0)

            echo
            echo "Done. decrypted=$decrypted  skipped=$skipped  failed=$failed  organised=$organised"
            echo "  Library:  $OUTPUT_DIR"
            echo "  Staging:  $STAGING_DIR   (encrypted originals kept — delete after verifying)"
    '';
  };
in
{
  options.features.audibleSync = {
    enable = lib.mkEnableOption "audible-sync — download + decrypt Audible library to .m4b";

    outputDir = lib.mkOption {
      type = lib.types.str;
      default = "~/audiobooks/audible";
      description = ''
        Destination for decrypted, organised .m4b files (one folder per book).
        Tilde is expanded at runtime against the invoking user's $HOME.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.audible-cli # `audible` CLI for one-time login + ad-hoc commands
      audibleSync # `audible-sync` end-to-end pipeline
    ];
  };
}
