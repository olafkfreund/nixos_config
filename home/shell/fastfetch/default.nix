# fastfetch — Alien HUD readout.
#
# Logo: the Aliens motion tracker (assets/logos/motion-tracker.gif), rendered
# to ANSI at BUILD time rather than by fastfetch's runtime `chafa` logo type.
# Runtime image logos need the terminal's pixel-per-cell size
# (getCharacterPixelDimensions); that query fails whenever stdout is not a
# real terminal and is unreliable through tmux and herdr — where this actually
# runs — and fastfetch then falls back to the built-in NixOS logo with no
# warning. Pre-rendering makes it deterministic everywhere, costs nothing at
# shell start, and pins the art in the store so razer gets the identical frame.
#
# Panel: the key holds a fixed-width box cell and the value prints outside it,
# which is the only way to get a boxed look out of fastfetch — it has no
# right-margin alignment. Keep `panelWidth` and the rule lines in step; the
# `row`/`rule` helpers below do the padding so nothing is hand-counted.
{ config, lib, pkgs, ... }:
let
  inherit (lib) concatStrings genList stringLength;
  inherit (config.lib.stylix) colors;

  # fastfetch emits whatever is inside {# } as an SGR sequence, so a truecolor
  # escape built from the Stylix palette keeps this file free of literal hex.
  sgr = name: "{#38;2;${colors."${name}-rgb-r"};${colors."${name}-rgb-g"};${colors."${name}-rgb-b"}}";
  green = sgr "base0B"; # phosphor — section titles, live values
  cream = sgr "base05"; # plate cream — labels
  dim = sgr "base03"; # hairline rules
  amber = sgr "base09"; # bar-graph amber — hardware
  cyan = sgr "base0C"; # readouts
  reset = "{#0}";

  panelWidth = 11; # inner label field, in cells
  pad = s: concatStrings (genList (_: " ") (panelWidth - stringLength s));

  # "  │ LABEL       │ " — the value lands after the closing bar.
  row = colour: label: "  ${dim}│ ${colour}${label}${pad label}${dim}│${reset} ";

  # "  ├─ TITLE ─────┤" — a section rule with an inline title, the plates'
  # panel-label tab. A bare string in `modules` is read as a module *name*, so
  # every drawn line has to be a custom module.
  #
  # Inner width is `panelWidth + 1` — the leading space in `row` plus the
  # label field. Lengths are measured on the ASCII title only: Nix's
  # stringLength counts bytes, and every box character here is 3 of them.
  innerWidth = panelWidth + 1;
  dashes = n: concatStrings (genList (_: "─") n);
  rule = left: right: title: {
    type = "custom";
    format = "  ${dim}${left}─ ${green}${title}${dim} ${dashes (innerWidth - 3 - stringLength title)}${right}${reset}";
  };

  plainRule = left: right: {
    type = "custom";
    format = "  ${dim}${left}${dashes innerWidth}${right}${reset}";
  };

  trackerGif = ../../../assets/logos/motion-tracker.gif;

  # Frame 16 of the tracker loop — sweep at full extent with the contact blip
  # visible. ImageMagick extracts the frame (chafa has no frame selector),
  # chafa turns it into truecolor symbols. `--polite on` keeps the
  # cursor-hide/show escapes out of the file so it can be dumped verbatim.
  #
  # `--symbols sextant` is what makes it legible. Symbol density sets the
  # sampling grid, not the cell size: at 40x20 cells half-blocks (1x2 per
  # cell) sample the image at only 40x40 px, which reduces the scope to a
  # green triangle with every arc and radial gone. Sextants (2x3) sample the
  # same 40x20 footprint at 80x60. Octants (2x4) would give 80x80, but they
  # are Unicode 16 and not reliably drawn yet; sextants are Unicode 13 and
  # foot/ghostty render them from their built-in glyph tables regardless of
  # the terminal font.
  trackerLogo = pkgs.runCommand "alien-tracker-logo.ans"
    {
      nativeBuildInputs = [ pkgs.imagemagick pkgs.chafa ];
    } ''
    magick "${trackerGif}[16]" frame.png
    chafa --format symbols --symbols sextant --size 40x20 \
          --colors full --animate off --polite on frame.png > $out
  '';

  # fastfetch prints one frame and exits — it has no animation of any kind,
  # for any logo type. The moving tracker lives here instead: chafa plays the
  # GIF itself. `tracker` loops until interrupted, `tracker 5` runs 5s.
  trackerAnim = pkgs.writeShellScriptBin "tracker" ''
    exec ${pkgs.chafa}/bin/chafa --symbols sextant --colors full \
         --size 40x20 --duration "''${1:-inf}" ${trackerGif}
  '';
in
{
  home.packages = [ trackerAnim ];

  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        type = "file-raw";
        source = "${trackerLogo}";
        width = 40;
        height = 20;
        padding = { top = 1; right = 3; };
      };
      display = {
        separator = " ";
      };
      modules = [
        {
          type = "custom";
          format = "  ${green}W E Y L A N D - Y U T A N I${reset}  ${dim}·${reset}  ${cream}CLASS M${reset}";
        }
        {
          type = "title";
          # A single space, not "": fastfetch reads an empty key as "unset"
          # and falls back to printing the module name ("Title:").
          key = " ";
          format = "${dim}UNIT${reset} ${green}{host-name}${reset}  ${dim}·${reset}  ${cream}{user-name}${reset}";
        }
        { type = "break"; }

        (rule "┌" "┐" "SYSTEM")
        { type = "os"; key = row cream "OS"; outputColor = "green"; }
        { type = "kernel"; key = row cream "KERNEL"; outputColor = "green"; }
        { type = "packages"; key = row cream "PACKAGES"; outputColor = "green"; }
        { type = "uptime"; key = row cream "UPTIME"; outputColor = "green"; }

        (rule "├" "┤" "HARDWARE")
        { type = "host"; key = row cream "CHASSIS"; outputColor = "yellow"; }
        { type = "cpu"; key = row cream "CPU"; outputColor = "yellow"; }
        { type = "gpu"; key = row cream "GPU"; outputColor = "yellow"; }
        { type = "memory"; key = row cream "MEMORY"; outputColor = "yellow"; }
        # Root only — the default lists every mount, which stacks three
        # identical DISK cells and breaks the panel's rhythm.
        { type = "disk"; key = row cream "DISK"; folders = "/"; outputColor = "yellow"; }

        (rule "├" "┤" "SESSION")
        { type = "wm"; key = row cream "WM"; outputColor = "cyan"; }
        { type = "shell"; key = row cream "SHELL"; outputColor = "cyan"; }
        { type = "terminal"; key = row cream "TERMINAL"; outputColor = "cyan"; }
        { type = "terminalfont"; key = row cream "FONT"; outputColor = "cyan"; }

        (rule "├" "┤" "LINK")
        { type = "localip"; key = row cream "IP"; format = "{ipv4} ({ifname})"; outputColor = "magenta"; }
        (plainRule "└" "┘")

        { type = "break"; }
        {
          type = "custom";
          format = "  ${dim}MU-TH-UR 6000${reset}  ${dim}·${reset}  ${amber}ENG-SYS${reset}  ${dim}·${reset}  ${cyan}ALL SUBSYSTEMS ${green}ONLINE${reset}";
        }
      ];
    };
  };
}
