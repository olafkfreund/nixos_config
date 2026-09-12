{ lib
, appimageTools
, fetchurl
,
}:
# BrowserOS — agentic Chromium fork; the AI browser as a desktop app rather
# than a tab. Upstream ships a Linux AppImage per release.
# Bump: `gh api "repos/browseros-ai/BrowserOS/releases?per_page=100" -q
# '.[] | select(.tag_name|test("^v[0-9]")) | .tag_name'` — the repo also tags
# `ext-agent/*` and `agent-server/*` far more often, and those are not the
# browser. Re-prefetch the x64 AppImage and update version+hash.
let
  pname = "browseros";
  version = "0.50.3";

  src = fetchurl {
    url = "https://github.com/browseros-ai/BrowserOS/releases/download/v${version}/BrowserOS_v${version}_x64.AppImage";
    hash = "sha256-Foln3alE/zGRYNF/p3hYL5CD5dvXapcouiClPej2DaQ=";
  };

  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -m444 -D ${appimageContents}/${pname}.desktop \
      -t $out/share/applications

    # `Exec=AppRun %U` -> our wrapper, keeping %U. Without it the entry takes
    # no argument and every x-scheme-handler/https hand-off opens a blank
    # window instead of the link.
    sed -i -E "s|^Exec=.*|Exec=${pname} %U|" \
      "$out/share/applications/${pname}.desktop"

    cp -r ${appimageContents}/usr/share/icons $out/share
  '';

  passthru.updateScript = ../../scripts/update-browseros.sh;

  meta = {
    description = "Agentic open-source browser, a privacy-first alternative to ChatGPT Atlas and Perplexity Comet";
    homepage = "https://browseros.com/";
    downloadPage = "https://github.com/browseros-ai/BrowserOS/releases";
    license = lib.licenses.agpl3Only;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
