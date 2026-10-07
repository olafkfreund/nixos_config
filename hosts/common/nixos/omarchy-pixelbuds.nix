# nixarchy-pixelbuds: Pixel Buds Pro battery (per bud + case) and
# listening modes in the Omarchy bar. The fork's flake patches upstream's
# /usr/bin/python3, gdbus and omarchy-shell to store paths (#2195).
#
# One-time step per machine:
#   omarchy plugin enable nixarchy.pixelbuds --section right
{ inputs, ... }:
{
  home-manager.users.olafkfreund =
    { pkgs, ... }:
    {
      programs.nixarchy.plugins."nixarchy.pixelbuds".src =
        inputs.nixarchy-pixelbuds.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };
}
