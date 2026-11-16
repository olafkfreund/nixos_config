# Omarchy, vendored for NixOS.
#
# Added to razer first, so the desktop p620 runs every day was not the one being
# experimented on. Both hosts carry it now and offer exactly two sessions,
# Omarchy and GNOME -- the niri, niri-dms, hyprland-dms and hyprland-uwsm
# entries this comment used to list are all gone.
{ config
, inputs
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
    ../../common/nixos/omarchy-layouts.nix
    ../../common/nixos/omarchy-keys.nix
    ../../common/nixos/bash-devshell-readline.nix
    ../../common/nixos/omarchy-sddm.nix
    ../../common/nixos/omarchy-gog.nix
    ../../common/nixos/omarchy-gmessages.nix
    ../../common/nixos/omarchy-plugin-browser.nix
    ../../common/nixos/omarchy-meet-binds.nix
    ../../common/nixos/omarchy-voice-pkgs.nix
    ../../common/nixos/omarchy-screenshots.nix
    ../../common/nixos/omarchy-ai-mirror.nix
    ../../common/nixos/omarchy-flea.nix
    ../../common/nixos/omarchy-nixi-companion.nix
    ../../common/nixos/nixi-fleet.nix
    ../../common/nixos/omarchy-microvm.nix
    ../../common/nixos/omarchy-omadroid.nix
    ../../common/nixos/omarchy-altscape.nix
    ../../common/nixos/omarchy-expose.nix
    ../../common/nixos/omarchy-omateams.nix
    ../../common/nixos/omarchy-hello-lock.nix
    ../../common/nixos/omarchy-omaoutlook.nix
    ../../common/nixos/omarchy-omamail.nix
    ../../common/nixos/omarchy-pixelbuds.nix
    ../../common/nixos/omarchy-meeting-mode.nix
    ../../common/nixos/llm-index.nix
    ../../common/nixos/omarchy-sole-hyprland.nix
    ../../common/nixos/omarchy-stylix-theme.nix
    ../../common/nixos/omarchy-t3code-theme.nix
    ../../common/nixos/omarchy-desktop.nix
  ];

  local.llmIndex.sourcePath = "/extdisk/Source"; # real path; ~/Source is a symlink; /extdisk is the second NVMe from fstab
  local.llmIndex.excludePaths = [ "/extdisk/Source/password" ];

  # psmisc is here for `fuser`, which Omarchy shell plugins call to find who
  # holds a lock or a device -- omachord's routine runner needs it and nothing
  # else in the closure pulls psmisc in, so the plugin fails at runtime rather
  # than at install with a message about a missing binary. p620 carries the
  # same line for the same reason.
  environment.systemPackages = [ pkgs.psmisc ];

  # gliff-server defaults to renderD128, the NVIDIA card; Hyprland renders on
  # the Intel iGPU, so capture fails there (#2251). by-path is PCI-stable.
  environment.variables.GLIFF_RENDER_NODE = "/dev/dri/by-path/pci-0000:00:02.0-render";

  # ~/.config/hypr/hyprland.lua is managed by home-manager here, so the seed
  # keeps it and Omarchy's own config is never installed. That is what the
  # Omarchy session entry is for: it runs Hyprland with --config against
  # Omarchy's hyprland.lua and needs no file of ours, so both desktops work.
  #
  # Plymouth is left alone deliberately: nixarchy only mkDefaults its own
  # splash, so stylix keeps this machine on 'stylix' with no mkForce needed.

  home-manager.users.olafkfreund = {
    imports = [
      # nixarchy-voice arrives through nixarchy now (it became a transitive
      # input of it), and nixarchy's home-manager module already pulls the
      # voice module in. Importing it here as well declares
      # `programs.omarchy-voice.enable` a second time and the whole host stops
      # evaluating. Re-add the explicit import only if nixarchy drops it again.
      inputs.nixarchy.homeManagerModules.nixarchy
    ];

    # nixi's optional integrations, from its own module rather than the 0.9
    # install.py copies they replace: the coaching watcher (at most one tip a
    # day, nothing leaves the machine) and the Omarchy hooks (a one-time
    # first-boot welcome, and a manual refresh after `omarchy update`).
    services.nixi = {
      watcher.enable = true;
      omarchyHooks.enable = true;

      # Named, because nixi's own default did not pin claude here and SUPER+H
      # died on "claude-agent-acp is not on the system PATH".
      #
      # Nixi defaults `agents` to
      #   lib.optional (pkgs.config.allowUnfree or false) "claude" ++ [ "codex" ]
      # and that allowUnfree test read FALSE in this machine's Home Manager
      # context, so the adapter was never pinned -- while
      # ~/.config/omarchy/defaults/agent still said `claude`. Nixi treats that
      # file as an EXPLICIT choice and will not fall back from it, so the card
      # threw rather than quietly using an agent it did have.
      #
      # Claude Code itself is installed outside Nix here (~/.local/bin, mise),
      # so nothing in the configuration implies it either.
      #
      # claude alone. This listed all three back when nixarchy predated the
      # release that names opencode and codex upstream -- nothing else defined
      # the option then, so a lone [ "claude" ] would have REPLACED rather than
      # added. The nixarchy this branch merges up to does name them, and the
      # option is a list, so the two sides merged and it evaluated to
      # [ opencode codex opencode codex claude ]. Naming only what upstream
      # does not give us keeps it to [ opencode codex claude ].
      agents = [ "claude" ];

    };

    # Oma's whisper.cpp takes Vulkan device 0, the Intel iGPU here: 1100 ms
    # encode, slower than the CPU. Device 1 is the RTX 3080: 7 ms. (#2113)
    systemd.user.services.omarchy-voice.Service.Environment = [ "GGML_VK_VISIBLE_DEVICES=1" ];

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

        # One TIMING line per turn in the session log: phase durations only,
        # never what was said. On to collect the before/after numbers for
        # nixarchy-voice #135 (streamed ElevenLabs) and #136 (resident Piper);
        # read them back with `tools/timing_report.py`.
        hands.trace_timings = true;
      };

      # SUPER + SHIFT + V, the upstream default, is taken on this machine --
      # as are SUPER + V and SUPER + CTRL + V. This is only printed as a build
      # warning: bindings.lua is hand-written and not ours to generate.
      keybinding = "SUPER + M";
    };
  };

  local.omarchy.keys = {
    workProfile = "Profile 5";
    calendarCommand = ''google-chrome-stable --profile-directory="Profile 5" --app="https://calendar.google.com/calendar/u/olaf@freundcloud.com/r"'';
  };
}
