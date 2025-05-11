{pkgs, ...}: let
  vars = import ../variables.nix;
in {
  time.timeZone = vars.timezone;

  i18n.defaultLocale = vars.locale;
  i18n.extraLocaleSettings = {
    LC_ADDRESS = vars.locale;
    LC_IDENTIFICATION = vars.locale;
    LC_MEASUREMENT = vars.locale;
    LC_MONETARY = vars.locale;
    LC_NAME = vars.locale;
    LC_NUMERIC = vars.locale;
    LC_PAPER = vars.locale;
    LC_TELEPHONE = vars.locale;
    LC_TIME = vars.locale;
  };
  console.keyMap = vars.keyboardLayout;
  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";
  services.xserver = {
    xkb.layout = vars.keyboardLayout;
    xkb.variant = "";
  };
}
