# Pin where Omarchy saves screenshots (omasnap --save, the preview's pin) rather
# than relying on omasnap's XDG default. A session variable, so the Hyprland
# login environment and every bind-launched capture inherit it.
_: {
  environment.sessionVariables.OMARCHY_SCREENSHOT_DIR = "$HOME/Pictures/Screenshots";
}
