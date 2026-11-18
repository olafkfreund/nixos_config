# OmaBroadcast (record, stream and compose live video) from the
# nixarchy-omabroadcast flake, which tracks upstream nightly (#3087).
{ inputs, ... }:
{
  imports = [ inputs.nixarchy-omabroadcast.nixosModules.default ];
  programs.omabroadcast.enable = true;
}
