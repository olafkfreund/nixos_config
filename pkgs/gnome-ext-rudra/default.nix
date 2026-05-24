{ lib
, stdenvNoCC
, fetchFromGitHub
, glib
}:
# Rudra — keyboard-driven productivity launcher for GNOME Shell.
# Upstream: https://github.com/NarkAgni/rudra
#
# Pinned to a master commit (not a release tag / extensions.gnome.org ZIP)
# because the maintainer hasn't published v8 yet. The latest ZIP on
# extensions.gnome.org is still the original v7 (February 2026), which is
# missing nearly every interesting feature that has since landed in master:
#   - AI Assistant with multi-provider dropdown (Gemini / Groq / Ollama /
#     Perplexity / Cohere), triggered with `?`
#   - Inline AI shortcuts: `px` (Perplexity) and `co` (Cohere) for quick answers
#   - Clipboard history manager, triggered with `cb`
#   - Developer plugins (Python / Bash), triggered with `p`
#   - Inline calculator (math expressions evaluate live, Enter copies result)
#   - DuckDuckGo search alongside Google + YouTube
#   - v8 UI overhaul, native settings icon, outside-click-to-close toggle
#   - Native GNOME 50 / 50.1 support in metadata.json (so no need for our
#     jq-patching workaround that the previous v7 ZIP fetcher used)
#
# When upstream cuts a real v8 release on extensions.gnome.org, this can be
# simplified back to a fetchurl-of-ZIP — but as long as that hasn't
# happened, the master pin is how we get the actually-shipped features.
#
# Install convention mirrors the upstream Makefile's `install` target,
# minus the user-local destination (we install to the Nix store and let
# Home Manager symlink it into ~/.local).
stdenvNoCC.mkDerivation rec {
  pname = "gnome-ext-rudra";
  version = "unstable-2026-03-25";
  uuid = "rudra@narkagni";

  src = fetchFromGitHub {
    owner = "NarkAgni";
    repo = "rudra";
    rev = "ecc3abd5b52f0cd1e698967dbdacbebad264bbbe";
    hash = "sha256-ddy0oEohJHbA09pAuFYFmo418bupQcAJIeVrjnaafEw=";
  };

  nativeBuildInputs = [ glib ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    target="$out/share/gnome-shell/extensions/${uuid}"
    install -d "$target"

    # Compile gsettings schemas before copying so the .compiled lands in place.
    glib-compile-schemas schemas

    # Mirror the upstream Makefile's install target.
    cp metadata.json   "$target/"
    cp extension.js    "$target/"
    cp prefs.js        "$target/"
    cp stylesheet.css  "$target/"
    cp LICENSE         "$target/"
    cp -r icons        "$target/"
    cp -r schemas      "$target/"

    # src/ subdirs. Using `cp -r src` rather than per-subdir copies (the
    # Makefile does per-subdir but the net effect is identical and this
    # form survives upstream adding new subdirs without a derivation bump).
    cp -r src          "$target/"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Keyboard-driven productivity launcher for GNOME Shell with AI / clipboard / plugins";
    longDescription = ''
      Rudra is a modern, deeply integrated launcher designed to replace the
      default GNOME overview. Pinned to upstream master (v8-in-development)
      until the maintainer publishes v8 to extensions.gnome.org — see the
      file header for the feature gap between the master HEAD and the latest
      published v7 ZIP.

      Default trigger: Ctrl + Shift + Space. Mode prefixes inside the
      launcher: `?` AI assistant, `cb` clipboard, `p` plugins, `.` files,
      `g`/`yt` web search, `>` command runner.
    '';
    homepage = "https://github.com/NarkAgni/rudra";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
