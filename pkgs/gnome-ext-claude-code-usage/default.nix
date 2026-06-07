{ lib
, stdenvNoCC
, fetchurl
, unzip
, glib
}:
stdenvNoCC.mkDerivation rec {
  pname = "gnome-ext-claude-code-usage";
  version = "4";
  uuid = "claude-code-usage@haletran.com";

  src = fetchurl {
    url = "https://extensions.gnome.org/extension-data/claude-code-usagehaletran.com.v${version}.shell-extension.zip";
    sha256 = "07wgwm6sbhldmlcv2b6pnwdmf21y59984vg3xavci9qjn9413ys8";
  };

  nativeBuildInputs = [ unzip glib ];

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -d "$out/share/gnome-shell/extensions/${uuid}"
    unzip -q "$src" -d "$out/share/gnome-shell/extensions/${uuid}"

    # Upstream v4 declares shell-version ["46","47","48","49"]; GNOME 50
    # then marks the extension incompatible (red icon). The extension is
    # a small panel indicator polling Anthropic's REST API for usage —
    # no GNOME 50-ABI-breaking surfaces — so widen the declared support
    # to include 50. Remove when upstream publishes a 50-native release.
    META="$out/share/gnome-shell/extensions/${uuid}/metadata.json"
    if ! grep -q '"50"' "$META"; then
      # sed -z reads the whole file as one record, letting the regex span
      # newlines (metadata.json formats shell-version as a multi-line array).
      sed -i -z 's/\("shell-version":[[:space:]]*\[[^]]*\)\]/\1,\n    "50"\n  ]/' "$META"
    fi

    if [ -d "$out/share/gnome-shell/extensions/${uuid}/schemas" ]; then
      glib-compile-schemas "$out/share/gnome-shell/extensions/${uuid}/schemas"
    fi
    runHook postInstall
  '';

  meta = with lib; {
    description = "Display Claude Code usage in the GNOME top panel";
    homepage = "https://github.com/Haletran/claude-usage-extension";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
