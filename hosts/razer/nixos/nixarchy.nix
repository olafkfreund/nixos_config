# Omarchy, vendored for NixOS.
#
# Added to razer first, so the desktop p620 runs every day was not the one being
# experimented on. Both hosts carry it now and offer exactly two sessions,
# Omarchy and GNOME -- the niri, niri-dms, hyprland-dms and hyprland-uwsm
# entries this comment used to list are all gone.
#
# The three settings below are what `nix run github:olafkfreund/nixarchy#doctor`
# printed for this machine. Each is here for a reason it named:
{ config
, inputs
, lib
, pkgs
, ...
}:
{
  # nixarchy-apply writes this host's selection to hosts/<hostname>/ when that
  # directory exists, and to the flake root only when it does not. It used to
  # land at the root and this line used to point there; once apply went
  # host-aware the two diverged in silence -- the root file went on building the
  # old selection while everything enabled from the menu was written per-host
  # and read by nobody (#1872, olafkfreund/nixarchy#734). So this path must name
  # the file apply actually writes for THIS host, never the flake root.
  imports = [
    inputs.nixarchy.nixosModules.nixarchy
    ../nixarchy-apps.nix
    ../../common/nixos/omarchy-input.nix
    ../../common/nixos/bash-devshell-readline.nix
    ../../common/nixos/omarchy-sddm.nix
    ../../common/nixos/omarchy-workspaces.nix
    ../../common/nixos/omarchy-gog.nix
    ../../common/nixos/omarchy-meet-binds.nix
    ../../common/nixos/omarchy-ai-mirror.nix
    ../../common/nixos/omarchy-gmessages.nix
    ../../common/nixos/omarchy-omadroid.nix
    ../../common/nixos/omarchy-sole-hyprland.nix
    ../../common/nixos/omarchy-stylix-theme.nix
  ];

  programs.nixarchy.enable = true;

  # Puts this user in the input group. Omarchy's shell reads the keyboard
  # device directly for its own key handling, which the group grants; without
  # it the session starts but never sees a keypress.
  programs.nixarchy.user = "olafkfreund";

  # Let theme switches tint Chrome/Chromium/Edge/Brave with the theme's accent
  # colour. Light and dark already follow the theme through the settings
  # portal without this; what it adds is the accent alone.
  #
  # The cost, stated upstream and worth keeping in view: Chromium reads policy
  # only from /etc/<browser>/policies/managed, with no per-user equivalent, so
  # this hands those directories to this user -- and whoever can write there
  # sets policy for the whole machine, forced extensions and proxies included.
  # On a single-user desktop that is moot. It does mean any process running as
  # olafkfreund can write Chrome policy, which now includes agents with shell
  # access (omarchy-voice's allow_shell on p620). Deliberately not on p510,
  # which also runs Omarchy.
  programs.nixarchy.browserThemeUser = "olafkfreund";

  # psmisc is here for `fuser`, which Omarchy shell plugins call to find who
  # holds a lock or a device -- omachord's routine runner needs it and nothing
  # else in the closure pulls psmisc in, so the plugin fails at runtime rather
  # than at install with a message about a missing binary. p620 carries the
  # same line for the same reason.
  environment.systemPackages = [ pkgs.psmisc ];

  # nixarchy pins its own Hyprland and does not defer -- nixpkgs defines
  # programs.hyprland.portalPackage at mkDefault priority, so matching it would
  # tie rather than yield, hence the force.
  #
  # There is no matching .package force any more: omarchy-sole-hyprland.nix
  # turns programs.hyprland off outright and restates what Nixarchy needs from
  # it, which is what stops a second Hyprland entry appearing at login.
  programs.hyprland.portalPackage = lib.mkForce pkgs.xdg-desktop-portal-hyprland;

  # Omarchy's SDDM greeter is the login manager. It replaced the
  # DankMaterialShell greetd greeter, which ran inside niri and went away
  # with niri and DMS. SDDM enumerates wayland-sessions, so GNOME stays
  # selectable alongside the Omarchy session.
  programs.nixarchy.displayManager = true;

  # Boot to Omarchy's splash, not stylix's. The option forces
  # boot.plymouth.theme and themePackages together on purpose: forcing the
  # name alone leaves NixOS asserting a theme that is not in the package list,
  # which fails the build.
  programs.nixarchy.bootSplash = "force";

  # ~/.config/hypr/hyprland.lua is managed by home-manager here, so the seed
  # keeps it and Omarchy's own config is never installed. That is what the
  # Omarchy session entry is for: it runs Hyprland with --config against
  # Omarchy's hyprland.lua and needs no file of ours, so both desktops work.
  #
  # Plymouth is left alone deliberately: nixarchy only mkDefaults its own
  # splash, so stylix keeps this machine on 'stylix' with no mkForce needed.

  home-manager.users.olafkfreund = {
    imports = [
      inputs.nixarchy.homeManagerModules.nixarchy
      inputs.nixarchy-voice.homeModules.default
    ];
    programs.nixarchy.enable = true;

    # nixi's optional integrations, from its own module rather than the 0.9
    # install.py copies they replace: the coaching watcher (at most one tip a
    # day, nothing leaves the machine) and the Omarchy hooks (a one-time
    # first-boot welcome, and a manual refresh after `omarchy update`).
    services.nixi = {
      watcher.enable = true;
      omarchyHooks.enable = true;
    };

    # Oma: speech to speech against the OpenAI Realtime API, driving Hyprland.
    #
    # The microphone starts off and only the toggle key opens it. While it is
    # open, room audio streams continuously to OpenAI; toggling off stops the
    # recorder rather than capturing and discarding, so nothing is picked up
    # while it is off.
    programs.omarchy-voice = {
      enable = true;

      # The key itself rather than a KEY=value file, which is what agenix
      # decrypts to. Read at start-up, so rotating it is a restart of the user
      # service and not a rebuild.
      apiKeyFile = config.age.secrets."api-openai".path;

      settings = {
        # Spoken status lines, in the local piper voice. Not the voice she
        # answers in: that is [realtime] voice, which arrives from OpenAI as
        # audio and never passes through piper.
        mouth.speak = true;

        # Off, and it has to stay off while a speaker rather than headphones
        # is the output. Her voice crosses the room back into the microphone,
        # the server reads it as a new user turn and cancels her reply
        # mid-word, and she never finishes a sentence. Headphones or
        # PipeWire's echo-cancel module make it safe to turn on.
        ears.barge_in = false;

        # The shell tool would let the model run arbitrary commands, on an
        # open microphone. What it needs for the desktop it gets through the
        # omarchy CLI and Hyprland dispatchers instead.
        hands.allow_shell = false;
      };

      # SUPER + SHIFT + V, the upstream default, is taken on this machine --
      # as are SUPER + V and SUPER + CTRL + V. This is only printed as a build
      # warning: bindings.lua is hand-written and not ours to generate.
      keybinding = "SUPER + M";
    };
  };
}
