# omarchy-voice's home-manager module defaults its package to the flake's own
# nixpkgs instance, which never sees overlays/upstream-fixes.nix. Its python
# closure (piper-tts -> pyopenjtalk-plus) then carries upstream breakage the
# overlay already fixes. Build it against our pkgs for those two arguments only;
# everything else is the same nixpkgs revision and stays cached.
{ pkgs, ... }:
{
  home-manager.sharedModules = [
    ({ options, ... }: {
      programs.omarchy-voice.package = options.programs.omarchy-voice.package.default.override {
        inherit (pkgs) python3Packages piper-tts;
      };
    })
  ];
}
