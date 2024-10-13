{
  self',
  pkgs,
  config,
  lib,
  ...
}: 
let
  inherit (lib.modules)  mkMerge;
in
{
  programs.mpv = {
    scripts = with pkgs.mpvScripts; [
      # from nixpkgs
      # cutter # cut and automatically concat videos
      mpris # MPRIS plugin
      # thumbnail # OSC seekbar thumbnails
      # thumbfast # on-the-fly thumbnailer
      # sponsorblock # skip sponsored segments
      # uosc # proximity UI
      # quality-menu # ytdl-format quality menu
      # seekTo # seek to specific pos.

      # from nyxpkgs
      # inputs'.nyxpkgs.packages.mpv-history # save a history of played files with timestamps
    ];

    config = {
      ytdl-format = "bestvideo+bestaudio/best";
      audio-display = false;
      force-window = true;
      hidpi-window-scale = false;
      hwdec = "auto";
      keep-open = true;
      keep-open-pause = false;
      osd-on-seek = false;
      profile = "gpu-hq";
      script-opts = "osc-seekbarstyle=knob,osc-deadzonesize=1,osc-minmousemove=1";
      slang = "chi";
      sub-auto = "fuzzy";
      sub-codepage = "gbk";
      osc = "no";
      osd-bar = "no";
      border = "no";
    };

    bindings = mkMerge [
      # mpv keybindings
      {
        "Y" = "add sub-scale +0.1"; # increase subtitle font size
        "G" = "add sub-scale -0.1"; # decrease subtitle font size
        "y" = "sub_step -1"; # immediately display next subtitle
        "g" = "sub_step +1"; # previous
        "R" = "cycle_values window-scale 2 0.5 1"; # switch between 2x, 1/2, unresized window size

        "l" = "seek 5";
        "h" = "seek -5";
        "j" = "seek -60";
        "k" = "seek 60";

        "s" = "cycle sub";
        "a" = "cycle audio";

        "Alt+h" = "add chapter -1";
        "Alt+l" = "add chapter 1";
        "Ctrl+SPACE" = "add chapter 1";

        "Alt+j" = "add video-zoom -0.25";
        "Alt+k" = "add video-zoom 0.25";

        "Alt+J" = "add sub-pos -1";
        "Alt+K" = "add sub-pos +1";

        "Ctrl+h" = "multiply speed 1/1.1";
        "Ctrl+l" = "multiply speed 1.1";
        "Ctrl+H" = "set speed 1.0";
      }
    ];
  };
}
