# Consolidated i18n.nix - used by all hosts
# Internationalization and localization settings from shared variables
{ lib, pkgs, ... }:
let
  # Import shared variables directly
  sharedVars = import ../shared-variables.nix;
in
{
  time.timeZone = sharedVars.localization.timezone;

  i18n.defaultLocale = sharedVars.localization.locale;
  i18n.extraLocaleSettings = {
    LC_ADDRESS = sharedVars.localization.locale;
    LC_IDENTIFICATION = sharedVars.localization.locale;
    LC_MEASUREMENT = sharedVars.localization.locale;
    LC_MONETARY = sharedVars.localization.locale;
    LC_NAME = sharedVars.localization.locale;
    LC_NUMERIC = sharedVars.localization.locale;
    LC_PAPER = sharedVars.localization.locale;
    LC_TELEPHONE = sharedVars.localization.locale;
    LC_TIME = sharedVars.localization.locale;
  };

  # Console configuration
  console.keyMap = sharedVars.localization.keyboardLayouts.console;
  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";

  # X server configuration (if keyboardLayouts.xserver exists)
  services.xserver = {
    xkb.layout = sharedVars.localization.keyboardLayouts.xserver or "gb";
    xkb.variant = "";
  };
}
