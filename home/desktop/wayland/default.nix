{ ... }: {
  # One Wayland session config per compositor, plus the shell/theming shared by
  # both. Values common to every session live in ./common.nix.
  #
  # labwc, mango and the Noctalia shell were removed 2026-08-21 — unused. niri
  imports = [
  ];
}
