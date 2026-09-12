# Omarchy, vendored for NixOS.
#
# Same settings as razer, and here for the same reasons -- the two machines are
# shaped alike: SDDM greeting, Omarchy the only Hyprland session, and the
# Omarchy theme driving stylix (modules/desktop/stylix-theme.nix).
#
# This host offers exactly two sessions, Omarchy and GNOME. The greetd/
# DankMaterialShell greeter, niri and the DMS sessions this comment used to
# describe are all gone.
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
  # us. razer has had this line since #1504; p620 never did, so the selection
  # landed in the flake and nothing read it. `dictation.enable = true` was
  # enabled in the menu, copied by apply, and built by nobody.
  imports = [
    inputs.nixarchy.nixosModules.nixarchy
    ../../../nixarchy-apps.nix
    ../../common/nixos/omarchy-input.nix
    ../../common/nixos/bash-devshell-readline.nix
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

  # ~/.config/hypr/hyprland.lua is home-manager's here, so the seed keeps it and
  # Omarchy's own config is never installed. The Omarchy session entry is what
  # makes that work: it runs Hyprland with --config against Omarchy's file and
  # needs nothing of ours, so both desktops coexist.
  #
  # Plymouth is left alone deliberately: nixarchy only mkDefaults its own
  # splash, so stylix keeps this machine on 'stylix' with no mkForce needed.

  # QtMultimedia for Omarchy shell plugins that want a camera preview
  # (io.github.kristoferlund.webcam). quickshell's wrapper injects only
  # qtdeclarative and qtwayland, so `import QtMultimedia` fails with "module is
  # not installed" and the plugin's whole Panel.qml refuses to load -- the bar
  # icon appears and clicking it does nothing.
  #
  # The wrapper *prefixes* NIXPKGS_QT6_QML_IMPORT_PATH rather than setting it,
  # so a value set here is preserved and searched. systemPackages is what puts
  # the multimedia backend under /run/current-system/sw/lib/qt-6/plugins, which
  # QT_PLUGIN_PATH already covers; only the QML path needs saying out loud.
  # psmisc is here for `fuser`, which Omarchy shell plugins call to find who
  # holds a lock or a device -- omachord's routine runner needs it and nothing
  # else in the closure pulls psmisc in, so the plugin fails at runtime rather
  # than at install with a message about a missing binary.
  environment.systemPackages = [ pkgs.qt6.qtmultimedia pkgs.psmisc ];
  environment.sessionVariables.NIXPKGS_QT6_QML_IMPORT_PATH =
    "${pkgs.qt6.qtmultimedia}/lib/qt-6/qml";

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
    # recorder rather than capturing and discarding.
    #
    # Set up on razer first and copied here unchanged. The one setting that is
    # a guess for this machine is barge_in, below.
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

        # Off, which is right for speakers and merely cautious for headphones.
        # With it on and a speaker as the output, her own voice crosses the
        # room into the microphone, the server reads it as a new user turn and
        # cancels her reply mid-word: she never finishes a sentence. That was
        # measured on razer. This machine's audio was not checked, so it stays
        # off until `omarchy-voice doctor` says what the devices here are.
        ears.barge_in = false;

        # Start a session by saying her name, rather than reaching for the key.
        #
        # This keeps a microphone open locally whenever listening is *not* on,
        # which is the thing being chosen here. Nothing reaches OpenAI until
        # the word is heard: the audio goes to whisper.cpp on this CPU, and
        # only once somebody actually speaks -- a silent room is never
        # transcribed at all, let alone uploaded.
        #
        # It is also what makes leaving listening switched on unnecessary,
        # which was the expensive habit: streamed room audio bills at the same
        # rate whether anyone is talking or not.
        #
        # Short names get misheard. Check `omarchy-voice log` for the
        # `wake ignored '...'` lines and add whatever spelling keeps coming
        # back as a second word -- "oma ohma" -- rather than arguing with the
        # transcriber about how it hears a name.
        ears.wake_word = "oma";

        # The shell tool would let the model run arbitrary commands, on an
        # open microphone. What it needs for the desktop it gets through the
        # omarchy CLI and Hyprland dispatchers instead.
        hands.allow_shell = false;
      };

      # Not the upstream SUPER + SHIFT + V. On razer all three V slots were
      # taken; this machine was not checked, so confirm with
      # `hyprctl binds -j` before trusting it.
      #
      # The module writes this to ~/.config/hypr/voice-binds.lua now rather
      # than printing it as a warning to paste. bindings.lua still has to load
      # it, with `pcall(require, "hypr.voice-binds")` -- activation says so
      # while that line is missing, and stops saying it once it is there.
      keybinding = "SUPER + M";
    };
  };
}
