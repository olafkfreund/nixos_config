{ lib
, appimageTools
, fetchurl
, makeWrapper
, webkitgtk_4_1
, glib-networking
, libsoup_3
,
}:
# GitHub Copilot desktop app — agent-native desktop experience for GitHub.
# Distributed as a Tauri AppImage from the public `github/app` release repo.
# Bump: see /update-* pattern — `gh release view --repo github/app` for the
# latest tag, then re-prefetch the linux-x64 AppImage and update version+hash.
let
  pname = "github-copilot-app";
  version = "1.0.10";

  src = fetchurl {
    url = "https://github.com/github/app/releases/download/v${version}/GitHub-Copilot-linux-x64.AppImage";
    hash = "sha256-VOtxGsIj8m/QBgiI2rowoYeUBbbl6Ks/lRFxrUKdAIk=";
  };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  nativeBuildInputs = [ makeWrapper ];

  # Tauri webview runtime: the AppImage bundles most libs, but webkit's TLS
  # backend (glib-networking) and libsoup must be resolvable for HTTPS in the
  # embedded webview.
  extraPkgs = _: [ webkitgtk_4_1 glib-networking libsoup_3 ];

  extraInstallCommands = ''
    # Desktop entry + icon names vary by release; glob them robustly.
    # The upstream Exec line names the AppImage's internal binary ("github");
    # rewrite the whole line to our wrapper, preserving the %u arg so the
    # x-scheme-handler/github-app deep links keep working.
    desktop=$(ls ${appimageContents}/*.desktop | head -1)
    install -m444 -D "$desktop" "$out/share/applications/${pname}.desktop"
    substituteInPlace "$out/share/applications/${pname}.desktop" \
      --replace-quiet 'Exec=AppRun' "Exec=${pname}"
    sed -i -E "s|^Exec=.*|Exec=${pname} %u|" "$out/share/applications/${pname}.desktop"

    if icon=$(ls ${appimageContents}/*.png 2>/dev/null | head -1); then
      install -m444 -D "$icon" \
        "$out/share/icons/hicolor/512x512/apps/${pname}.png"
    fi
    if [ -d ${appimageContents}/usr/share/icons ]; then
      cp -r ${appimageContents}/usr/share/icons "$out/share/" || true
    fi

    wrapProgram "$out/bin/${pname}" \
      --set XDG_CURRENT_DESKTOP GNOME
  '';

  meta = {
    description = "GitHub Copilot agent-native desktop app";
    homepage = "https://github.com/features/ai/github-app";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
