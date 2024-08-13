{ config, pkgs, ... }:
# ---------------------------------------------------------------------
# Setup auto randering when monitors / external moniters plugged in
# ---------------------------------------------------------------------
{
  services = {

    autorandr.enable = false;
    udev.extraRules = ''
      ACTION=="change", SUBSYSTEM=="drm", RUN+="${pkgs.autorandr}/bin/autorandr -c"'';

  };

  powerManagement = {

    resumeCommands = "${pkgs.autorandr}/bin/autorandr -c";

  };
}
