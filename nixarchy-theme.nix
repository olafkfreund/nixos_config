# The Omarchy theme the flake builds against. Rewritten by the theme-set
# hook in hosts/common/nixos/omarchy-stylix-theme.nix on every
# `omarchy theme set`, so the next rebuild carries the same palette into
# everything Stylix owns and Omarchy cannot reach at runtime -- Plymouth,
# GRUB, the console, fonts, and the remaining home-manager targets.
#
# Edit by switching themes, not by hand: a hand edit is overwritten the
# next time a theme is set.
"catppuccin"
