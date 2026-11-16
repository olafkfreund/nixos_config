{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, copyDesktopItems
, makeDesktopItem
, libxkbcommon
, libxcb
, vulkan-loader
, libglvnd
, wayland
, curl
, pipewire
, herdr-core
, herdr-app-sync
, util-linux
, linkFarm
, writeText
, runCommand
}:
# Herdr's prebuilt native desktop app.
# Bump: version + sha256 from https://releases.herdr.dev/app/latest.json,
# then re-run Verification 6 on p620.
let
  version = "0.1.16";

  releases = linkFarm "herdr-releases" [
    { name = "app/latest.json"; path = writeText "app.json" (builtins.toJSON { inherit version; }); }
    { name = "core/latest.json"; path = writeText "core.json" (builtins.toJSON { version = herdr-core.version; generation = 1; }); }
  ];

  # A window launch (no arguments) syncs the declared mods, layout and keys
  # first (#2978). With no app home yet, the app makes it, so sync after it has.
  syncOnLaunch = ''
    if [ "$#" -eq 0 ] && [ -z "''${HERDR_APP_SYNC_RUNNING:-}" ]; then
      export HERDR_APP_SYNC_RUNNING=1
      if [ -d "''${HERDR_APP_HOME:-$HOME/.config/herdr-app}" ]; then
        herdr-app-sync || :
      else
        ${util-linux}/bin/setsid -f sh -c 'sleep 20; herdr-app-sync' >/dev/null 2>&1 || :
      fi
    fi
  '';

  frontmatter = writeText "herdr-app-skill-frontmatter" ''
    ---
    name: herdr-app
    description: "Drive the person's Herdr desktop window (spaces, tabs, panes) with herdr-app. Use only when the user asks to arrange or show something in the Herdr app; terminals and agents themselves are the hc skill."
    ---
  '';
in
stdenv.mkDerivation (finalAttrs: {
  pname = "herdr-app";
  inherit version;

  src = fetchurl {
    url = "https://releases.herdr.dev/app/${version}/herdr-app-linux-x86_64.tar.gz";
    sha256 = "282d2632196b238206cfe66bfb61c0faf299ca1c91843bd076521bbe36571216";
  };

  sourceRoot = "herdr-app";

  nativeBuildInputs = [ autoPatchelfHook makeWrapper copyDesktopItems ];
  buildInputs = [ libxkbcommon libxcb stdenv.cc.cc.lib ];
  # dlopen'd GPU/Wayland libs go into RUNPATH, not LD_LIBRARY_PATH, which hc terminals would inherit.
  runtimeDependencies = [ vulkan-loader libglvnd wayland libxkbcommon ];

  installPhase = ''
    runHook preInstall

    install -Dm755 herdr-app "$out/bin/herdr-app"
    # update::find_root needs the SVG beside the canonicalised exe; leaving it out disables the in-app updater.
    install -Dm444 herdr-app.svg "$out/share/icons/hicolor/scalable/apps/herdr-app.svg"
    install -Dm444 LICENSE THIRD-PARTY-NOTICES -t "$out/share/doc/herdr-app"

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "herdr-app";
      desktopName = "Herdr";
      exec = "herdr-app";
      icon = "herdr-app";
      categories = [ "Development" "TerminalEmulator" ];
      comment = "Native app for running coding agents";
    })
  ];

  postFixup = ''
    wrapProgram "$out/bin/herdr-app" \
      --prefix PATH : "${lib.makeBinPath [ curl pipewire herdr-core ]}" \
      --set HERDR_CORE_DIRS "${herdr-core}/bin" \
      --set HERDR_RELEASES_URL "file://${releases}" \
      --set HERDR_TELEMETRY 0 \
      --set DO_NOT_TRACK 1 \
      --prefix PATH : "${lib.makeBinPath [ herdr-app-sync ]}" \
      --run ${lib.escapeShellArg syncOnLaunch}
  '';

  passthru.skill = runCommand "herdr-app-skill" { } ''
    mkdir -p $out
    { cat ${frontmatter}; HOME=$TMPDIR ${finalAttrs.finalPackage}/bin/herdr-app --skill; } > $out/SKILL.md
  '';

  meta = {
    description = "Native desktop app for running coding agents with Herdr";
    homepage = "https://herdr.dev";
    license = lib.licenses.asl20;
    mainProgram = "herdr-app";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
