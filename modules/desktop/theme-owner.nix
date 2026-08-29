{ config, lib, pkgs, ... }:
# Session-scoped theme ownership.
#
# Three systems want to colour the same applications and disagree about who
# owns the config FILE, not about the colours:
#
#   stylix   build time  — generates the whole app config into the store
#   DMS      runtime     — matugen writes ~/.config/<app>/dank-theme.*
#   omarchy  runtime     — omarchy-theme-set writes
#                          ~/.local/state/omarchy/current/theme/<app>.*
#
# Both runtime systems assume the app config is a hand-editable file with an
# include line. Stylix's model is the opposite, which is why omarchy has been
# generating a full theme set on this machine that nothing reads: every
# terminal config is a read-only store symlink.
#
# The resolution is an indirection symlink per app. Each terminal's config
# imports a stable path this module owns; a session-start unit points that path
# at whichever system owns the current session. Nothing about the app config
# changes at runtime, so home-manager keeps owning it exactly as before.
#
# Stylix still wins everywhere it is the only candidate — GRUB, Plymouth,
# console, greeter, fonts, cursors, icons — and this module never touches those.
with lib;
let
  cfg = config.features.themeOwner;
  c = config.home-manager.users.${cfg.user}.lib.stylix.colors;

  # base16 -> ANSI, the standard mapping. Named so the terminal templates below
  # read as colour roles rather than as sixteen opaque indices.
  ansi = [
    c.base00
    c.base08
    c.base0B
    c.base0A
    c.base0D
    c.base0E
    c.base0C
    c.base05
    c.base03
    c.base08
    c.base0B
    c.base0A
    c.base0D
    c.base0E
    c.base0C
    c.base07
  ];
  nth = i: elemAt ansi i;
  idx = range 0 15;

  # The fallback palette, in each terminal's own syntax.
  #
  # This exists because the stylix target for these terminals has to be OFF.
  # Alacritty resolves `general.import` so that the IMPORTING file wins, and
  # foot merges later sections over earlier includes — in both, a stylix-written
  # palette in the main config outranks anything a runtime owner drops in, so
  # the include would be decorative. With the target off the main config carries
  # no colours at all and the import is the only source, which then needs a
  # floor for the first login before either owner has generated anything.
  fallbacks = pkgs.runCommand "theme-owner-fallback" { } ''
    mkdir -p $out

    {
      echo '[colors.primary]'
      echo 'background = "#${c.base00}"'
      echo 'foreground = "#${c.base05}"'
      echo '[colors.normal]'
      echo 'black = "#${nth 0}"'
      echo 'red = "#${nth 1}"'
      echo 'green = "#${nth 2}"'
      echo 'yellow = "#${nth 3}"'
      echo 'blue = "#${nth 4}"'
      echo 'magenta = "#${nth 5}"'
      echo 'cyan = "#${nth 6}"'
      echo 'white = "#${nth 7}"'
      echo '[colors.bright]'
      echo 'black = "#${nth 8}"'
      echo 'red = "#${nth 9}"'
      echo 'green = "#${nth 10}"'
      echo 'yellow = "#${nth 11}"'
      echo 'blue = "#${nth 12}"'
      echo 'magenta = "#${nth 13}"'
      echo 'cyan = "#${nth 14}"'
      echo 'white = "#${nth 15}"'
    } > $out/alacritty.toml

    {
      echo 'background #${c.base00}'
      echo 'foreground #${c.base05}'
      ${concatStringsSep "\n" (map (i: "echo 'color${toString i} #${nth i}'") idx)}
    } > $out/kitty.conf

    {
      # [colors-dark], not the deprecated [colors]: foot warns once per launch
      # about the latter, and both runtime owners write [colors-dark] too, so
      # the fallback matching them keeps the three files interchangeable.
      echo '[colors-dark]'
      echo 'background=${c.base00}'
      echo 'foreground=${c.base05}'
      ${concatStringsSep "\n" (map (i: "echo '${toString i}=${nth i}'") idx)}
    } > $out/foot.ini

    {
      echo 'background = #${c.base00}'
      echo 'foreground = #${c.base05}'
      ${concatStringsSep "\n" (map (i: "echo 'palette = ${toString i}=#${nth i}'") idx)}
    } > $out/ghostty.conf
  '';

  # link = the path the app imports (this module owns it, home-manager must not)
  # dms / omarchy = what each owner writes, when it has run at least once
  apps = {
    alacritty = {
      link = ".config/alacritty/theme-active.toml";
      dms = ".config/alacritty/dank-theme.toml";
      omarchy = ".local/state/omarchy/current/theme/alacritty.toml";
      fallback = "${fallbacks}/alacritty.toml";
    };
    kitty = {
      link = ".config/kitty/theme-active.conf";
      dms = ".config/kitty/dank-theme.conf";
      omarchy = ".local/state/omarchy/current/theme/kitty.conf";
      fallback = "${fallbacks}/kitty.conf";
    };
    foot = {
      link = ".config/foot/theme-active.ini";
      dms = ".config/foot/dank-colors.ini";
      omarchy = ".local/state/omarchy/current/theme/foot.ini";
      fallback = "${fallbacks}/foot.ini";
    };
    ghostty = {
      link = ".config/ghostty/theme-active.conf";
      dms = ".config/ghostty/dank-theme.conf";
      omarchy = ".local/state/omarchy/current/theme/ghostty.conf";
      fallback = "${fallbacks}/ghostty.conf";
    };
  };

  # One `ln -sfn` per app, choosing the first source that exists. A dangling
  # symlink is worse than a plain fallback here: foot and alacritty both log on
  # every launch when an import cannot be resolved.
  linkLines = concatStringsSep "\n" (mapAttrsToList
    (name: a: ''
      resolve ${escapeShellArg name} \
        "$HOME/${a.link}" \
        "$HOME/${a.dms}" \
        "$HOME/${a.omarchy}" \
        ${escapeShellArg a.fallback}
    '')
    apps);

  themeOwner = pkgs.writeShellApplication {
    name = "theme-owner";
    runtimeInputs = [ pkgs.coreutils pkgs.systemd ];
    text = ''
      # Which system owns the colours right now. An explicit argument wins;
      # otherwise detect the session.
      #
      # NOT by OMARCHY_PATH. The nixarchy module exports it through
      # environment.sessionVariables, so it is set in every shell on any host
      # where nixarchy is installed — an ssh session with no desktop at all
      # answers to it. It says nixarchy exists, not that Omarchy is running,
      # and trusting it handed omarchy the colours in every DMS session too.
      #
      # XDG_CURRENT_DESKTOP is no good either: it reads Hyprland for the
      # Omarchy session, because xdg-desktop-portal-hyprland refuses to bind
      # for anything else. XDG_SESSION_DESKTOP carries the session name.
      #
      # A systemd user unit does not always inherit it, so fall back to
      # asking logind for the session Desktop directly. If both come up empty
      # the answer is omarchy: since DMS and niri were removed it is the only
      # shell that owns terminal colours here.
      owner="''${1:-}"
      if [ -z "$owner" ]; then
        desktop="''${XDG_SESSION_DESKTOP:-}"
        if [ -z "$desktop" ]; then
          sid=$(loginctl show-user "$(id -u)" -p Display --value 2>/dev/null || true)
          if [ -n "$sid" ]; then
            desktop=$(loginctl show-session "$sid" -p Desktop --value 2>/dev/null || true)
          fi
        fi
        case "$(printf '%s' "$desktop" | tr '[:upper:]' '[:lower:]')" in
          *)         owner=omarchy ;;
        esac
        echo "theme-owner: session desktop ''${desktop:-unknown} -> $owner" >&2
      fi

      case "$owner" in
        dms|omarchy) ;;
        *) echo "theme-owner: unknown owner '$owner' (want dms or omarchy)" >&2; exit 1 ;;
      esac

      resolve() {
        local app=$1 link=$2 dms=$3 omarchy=$4 fallback=$5 target
        case "$owner" in
          dms)     target=$dms ;;
          omarchy) target=$omarchy ;;
        esac
        if [ ! -e "$target" ]; then
          echo "theme-owner: $app has no $owner theme yet, using the stylix fallback" >&2
          target=$fallback
        fi
        mkdir -p "$(dirname "$link")"
        ln -sfn "$target" "$link"
      }

      ${linkLines}

      mkdir -p "$HOME/.local/state"
      echo "$owner" > "$HOME/.local/state/theme-owner"
      echo "theme-owner: colours now owned by $owner"
    '';
  };
in
{
  options.features.themeOwner = {
    enable = mkEnableOption "session-scoped theme ownership (DMS in DMS sessions, omarchy in the Omarchy session)";

    user = mkOption {
      type = types.str;
      default = "olafkfreund";
      description = "The user whose home the indirection symlinks live in.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ themeOwner ];

    # DMS only installs matugen, and only generates its theme files, when this
    # is set. Without it the DMS side of every symlink is permanently missing
    # and the fallback is all you would ever see.
    programs.dms-shell.enableDynamicTheming = true;

    # graphical-session.target is reached by both the niri/Hyprland DMS
    # launchers and by uwsm in the Omarchy session, so one unit covers every
    # session without wrapping any of their Exec lines.
    systemd.user.services.theme-owner = {
      description = "Point the per-app theme symlinks at this session's owner";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${themeOwner}/bin/theme-owner";
      };
    };

    home-manager.users.${cfg.user} = _: {
      # Off for exactly the terminals whose include semantics cannot override an
      # in-file palette. Their colours now come through theme-active.* only,
      # with the fallback above standing in for stylix.
      # mkForce because Users/common/base-home.nix asserts ghostty.enable = true
      # fleet-wide; the other three only carry stylix's autoEnable default, but
      # they are forced too so a reader does not have to work out which is which.
      stylix.targets = {
        alacritty.enable = mkForce false;
        kitty.enable = mkForce false;
        foot.enable = mkForce false;
        ghostty.enable = mkForce false;
      };

      programs = {
        # Imports are resolved in order and the LAST one wins, so this must stay
        # the only import and the file itself must carry no colours.
        alacritty.settings.general.import = [ "~/${apps.alacritty.link}" ];

        # kitty's extraConfig lands at the end of the file, where an include
        # outranks everything above it. kitty and ghostty both resolve a
        # relative include against their own config dir; foot and alacritty
        # want the path spelled out.
        kitty.extraConfig = mkAfter ''
          include ${baseNameOf apps.kitty.link}
        '';

        foot.settings.main.include = "~/${apps.foot.link}";

        ghostty.settings.config-file = baseNameOf apps.ghostty.link;
      };
    };
  };
}
