# opencode from upstream's own release binary, because the nixpkgs build is
# broken (#1859).
#
# nixpkgs compiles opencode with bun 1.4.2, which miscompiles it: the binary
# starts, but every prompt dies in SystemPrompt.environment with
#
#   TypeError: undefined is not an object (evaluating 'a.name')
#
# That is NixOS/nixpkgs#563241. Upstream's own 1.18.30 and 1.18.31 binaries
# both work on these machines; the nixpkgs one fails wrapped and unwrapped, on
# p620 and razer, with an empty config and no plugin.
#
# DELETE THIS PACKAGE when nixpkgs ships the fix:
#
#     nix eval --raw nixpkgs#opencode.version    # >= 1.18.31 means it is time
#
# then put `pkgs.opencode` back in home/default.nix (#1851) and remove the
# flake.nix entry.
{ lib
, stdenvNoCC
, fetchurl
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "opencode-bin";
  version = "1.18.31";

  src = fetchurl {
    url = "https://github.com/sst/opencode/releases/download/v${finalAttrs.version}/opencode-linux-x64.tar.gz";
    hash = "sha256-6TEr517YA7dBX8Kuq9ofT+k4kSo5Zzdi3Aw4wOEeveQ=";
  };

  sourceRoot = ".";

  # A bun single-file executable: it carries its own runtime and needs no
  # interpreter or library rewriting, which is how upstream ships it.
  dontPatchELF = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 opencode $out/bin/opencode
    runHook postInstall
  '';

  meta = {
    description = "AI coding agent for the terminal (upstream binary; see the note above)";
    homepage = "https://opencode.ai";
    license = lib.licenses.mit;
    mainProgram = "opencode";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
