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
, linkFarm
, writeText
, runCommand
}:
# Herdr's prebuilt native desktop app.
# Bump: version + sha256 from https://releases.herdr.dev/app/latest.json,
# then re-run Verification 6 on p620.
let
  version = "0.1.15";

  releases = linkFarm "herdr-releases" [
    { name = "app/latest.json"; path = writeText "app.json" (builtins.toJSON { inherit version; }); }
    { name = "core/latest.json"; path = writeText "core.json" (builtins.toJSON { version = herdr-core.version; generation = 1; }); }
  ];

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
    sha256 = "f99e1e04be82c0e10b2f69ee7403ca34386f480d92511df5865af4703e7655dd";
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
      --set DO_NOT_TRACK 1
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
