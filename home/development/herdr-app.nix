# herdr-app: the mods, layout, settings and keys it shares with the TUI workflow (#2978).
#
# The app owns ~/.config/herdr-app (it rewrites shipped mods and writes its own
# JSON), so nothing here is a store symlink. herdr-app-sync copies these in on
# every switch and every window launch, keeps a manifest, and backs up anything
# it replaces under ~/.local/state/herdr-app-sync/backups/.
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.herdrSkill;

  issues = pkgs.fetchFromGitHub {
    owner = "jankeesvw";
    repo = "herdr-issues";
    rev = "15ffaad00d37efe17ef952109a3198fe299ecb67";
    hash = "sha256-zj3BoGuCSdY0AoV5KI0oS0EEm0AtVtmHlIi0yEMsH/I=";
  };
  gitlab = pkgs.fetchFromGitHub {
    owner = "rem-aster";
    repo = "herdr-gitlab";
    rev = "dc4931a029f827c93632931a2e940a93b9a2da51";
    hash = "sha256-AKSirvOamYWeNBtsGkVzZUtlF2zlr9lr/xxr+fTCRN0=";
  };

  ours = [ "inbox" "notify" "splits" "freund-tabs" "freund-agents" ];

  open = argv: place: { command = "terminal.open"; args = { inherit argv place; }; };
  dirs = [ "left" "down" "up" "right" ];
  bind = prefix: cmd: lib.listToAttrs (lib.zipListsWith
    (key: dir: lib.nameValuePair "${prefix}-${key}" "splits.${cmd}-${dir}") [ "h" "j" "k" "l" ]
    dirs);

  keys = {
    # ctrl+hjkl moves and alt+hjkl resizes, through Neovim splits too (alt-hjkl
    # replaces the app's pane.go on purpose: that is ctrl's job now).
    terminal = bind "ctrl" "go" // bind "alt" "resize";
    global = {
      "ctrl-shift-g" = open [ "lazygit" ] "tab";
      "ctrl-shift-y" = open [ "zoe" ] "right";
      "ctrl-alt-shift-y" = open [ "zoe" ] "tab";
      "ctrl-shift-u" = "splits.worktree-open";
      "ctrl-shift-i" = "mod.open:inbox";
    };
  };

  source = pkgs.linkFarm "herdr-app-sync-source" (
    map (name: { name = "mods/${name}"; path = ./herdr-app/mods + "/${name}"; }) ours
    ++ [
      { name = "mods/issues"; path = "${issues}/mods/issues"; }
      { name = "mods/gitlab"; path = "${gitlab}/mods/gitlab"; }
      { name = "layouts/freund.json"; path = ./herdr-app/layouts/freund.json; }
      {
        name = "settings.json";
        path = pkgs.writeText "settings.json" (builtins.toJSON { theme = "omarchy"; sounds.enabled = true; });
      }
      { name = "keys.json"; path = pkgs.writeText "keys.json" (builtins.toJSON keys); }
      {
        name = "managed.json";
        path = pkgs.writeText "managed.json" (builtins.toJSON {
          mods = ours ++ [ "issues" "gitlab" ];
          layouts = [ "freund" ];
          first_layout = "freund";
        });
      }
    ]
  );
in
{
  config = lib.mkIf cfg.enable {
    xdg.configFile."herdr-app-sync/source".source = source;

    home.activation.herdrAppSync = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.customPkgs.herdr-app-sync}/bin/herdr-app-sync || true
    '';
  };
}
