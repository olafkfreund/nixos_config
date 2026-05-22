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
