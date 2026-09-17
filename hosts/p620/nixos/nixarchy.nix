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

    # nixarchy packages: search nixpkgs, turn curated apps and services on,
    # set NixOS options, queue and apply -- from the Omarchy shell rather
    # than a terminal. A front-end only: every write goes through the
    # nixarchy writers this module already installs.
    #
    # Installed, not enabled. Enabling a plugin is runtime state in
    # shell.json, which nixarchy leaves alone on purpose, so once per machine:
    #   omarchy plugin enable nixarchy.pkg
    # A chord is yours to choose too; SUPER+ALT+N is free in Omarchy's set.
    programs.nixarchy.plugins."nixarchy.pkg".src =
      inputs.nixarchy-pkg.packages.${pkgs.stdenv.hostPlatform.system}.default;

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

      # The cloud voice. Optional in the strongest sense: unreadable is a
      # warning, not a failure, and the local Piper voice carries on.
      elevenLabsKeyFile = config.age.secrets."api-elevenlabs".path;

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
        # Wake word OFF. Not because it did not work -- it did -- but because
        # of what it costs while nobody is talking: the listener transcribes
        # every sound near the microphone to find out whether it was her name,
        # and on this desk that was whisper sitting at 150-370% CPU whenever
        # anything was playing. SUPER + M costs nothing at all until pressed.
        #
        # Set it back to "oma" if hands-free is worth a core; the machinery is
        # all still here and tested.
        ears.wake_word = "";

        # Speak through ElevenLabs, with Piper underneath.
        #
        # Tarquin, "Posh & English RP" -- a voice-library voice, which needs a
        # paid plan: on free it is refused with "Free users cannot use library
        # voices via the API" and every reply silently falls back to Piper. If
        # the plan ever lapses that is exactly what happens, and the log says
        # so rather than going quiet.
        #
        # The premade British voices work on any tier if you want one:
        # Alice (clear, neutral)  Xb7hH8MSUJpSbSDYk0k2
        # Lily  (warmer)          pFZP5JQG7iQjIQuC4Bku
        elevenlabs.enabled = true;
        elevenlabs.voice_id = "7cOBG34AiHrAzs842Rdi";

        # The offline rung of the brain ladder. Claude Code answers whenever
        # api.anthropic.com is reachable; when it is not, this is what answers
        # instead, and a local endpoint is not asked for an API key.
        #
        # qwen3:14b rather than a coder model on purpose -- the planner asks
        # for function calls, and qwen2.5-coder:14b returned the JSON as prose
        # instead of calling anything. Measured, not assumed.
        openai.base_url = "http://localhost:11434/v1";
        openai.planner_model = "qwen3:14b";

        # Full control by voice: the shell tool and hl.dsp.exec are on. The
        # deny list (sudo, rm -rf, dd, ssh, git push, nix gc) and the confirm
        # list (shutdown, reboot, nixos-rebuild) still apply to every command.
        hands.allow_shell = true;

        # ssh allowed by voice. Config deny rules are ADDED to the built-in list
        # and none can be removed, so this is the built-in list (omarchy_voice
        # config.py DEFAULT_DENY) minus \bssh\b, replacing it. The ceiling: a
        # rule added upstream later does not reach this host until copied here.
        hands.deny_patterns_replace = true;
        hands.deny_patterns = [
          "\\brm\\s+-[a-zA-Z]*[rf]"
          "\\bmkfs\\b"
          "\\bdd\\s+if="
          "\\b(shred|wipefs)\\b"
          ">\\s*/dev/[sn][dv]"
          "\\bpasswd\\b"
          "\\bsudo\\b"
          "\\bpkexec\\b"
          "\\bcryptsetup\\b"
          "\\bcurl\\b.*\\|\\s*(bash|sh)"
          "\\bgit\\s+push\\b"
          "\\bnix-collect-garbage\\b"
          "\\bnix\\s+store\\s+(delete|gc)\\b"
          "\\bnix-store\\s+--delete\\b"
          "\\bnix\\s+profile\\s+wipe-history\\b"
          "\\bnix-env\\s+--delete-generations\\b"
        ];

        # A screenshot -> click -> check loop through ai-mirror spends a round
        # per step; 12 ran out halfway through a dialog.
        openai.max_turns = 40;
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
