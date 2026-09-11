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
  # nixarchy-apply copies ~/.config/nixarchy/apps.nix to the flake root as
  # nixarchy-apps.nix and stops there -- a flake cannot read a file outside its
  # own tree, so the selection has to be copied in, and importing it is left to
  # you. Without this line the Omarchy menu appears to enable applications and
  # nothing is ever built. Only razer imports it; p620 has its own nixarchy and
  # would otherwise inherit this machine's selection.
  imports = [
    inputs.nixarchy.nixosModules.nixarchy
    ../../../nixarchy-apps.nix
    ../../common/nixos/omarchy-input.nix
    ../../common/nixos/omarchy-sddm.nix
    ../../common/nixos/omarchy-workspaces.nix
    ../../common/nixos/omarchy-gog.nix
    ../../common/nixos/omarchy-meet-binds.nix
    ../../common/nixos/omarchy-sole-hyprland.nix
    ../../common/nixos/omarchy-stylix-theme.nix
  ];

  programs.nixarchy.enable = true;

  # Puts this user in the input group. Omarchy's shell reads the keyboard
  # device directly for its own key handling, which the group grants; without
  # it the session starts but never sees a keypress.
  programs.nixarchy.user = "olafkfreund";

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
