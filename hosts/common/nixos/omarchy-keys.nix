{ config, lib, pkgs, ... }:
let
  cfg = config.local.omarchy.keys;
  binding = lib.types.submodule {
    options = {
      key = lib.mkOption { type = lib.types.str; };
      description = lib.mkOption { type = lib.types.str; };
      action = lib.mkOption { type = lib.types.str; };
      lua = lib.mkOption { type = lib.types.bool; default = false; };
    };
  };
  external = lib.types.submodule {
    options = {
      key = lib.mkOption { type = lib.types.str; };
      description = lib.mkOption { type = lib.types.str; };
    };
  };
  keys = cfg.shared ++ cfg.extra;
  modifiers = [ "SUPER" "CTRL" "ALT" "SHIFT" ];
  normalise = chord:
    let
      parts = map lib.toUpper (builtins.filter (part: builtins.isString part && part != "") (builtins.split "[+[:space:]]+" chord));
      prefix = if parts == [ ] then [ ] else lib.init parts;
    in
    lib.concatStringsSep "+" (
      lib.filter (modifier: lib.elem modifier prefix) modifiers
      ++ lib.filter (part: !lib.elem part modifiers) prefix
      ++ lib.optional (parts != [ ]) (lib.last parts)
    );
  chords = map (entry: normalise entry.key) (keys ++ cfg.external);
  profiles = { p620 = "4"; razer = "5"; };
  profile = profiles.${config.networking.hostName} or null;
  otherProfile = if profile == "4" then "5" else "4";
  repoLua = ''
    local function load(name)
      if not package.searchpath(name, package.path) then
        return
      end
      local ok, err = pcall(require, name)
      if not ok then
        hl.exec_cmd("omarchy-notification-send " .. o.shell_quote(name .. " failed: " .. tostring(err)))
      end
    end
    ${lib.concatMapStringsSep "\n" (name: "load(${builtins.toJSON name})") cfg.fragments}
    ${lib.concatMapStringsSep "\n" (key: "hl.unbind(${builtins.toJSON key})") cfg.unbind}
    ${lib.concatMapStringsSep "\n" (key: ''
      hl.unbind(${builtins.toJSON key.key})
      o.bind(${builtins.toJSON key.key}, ${builtins.toJSON key.description}, ${if key.lua then key.action else builtins.toJSON key.action})
    '') keys}
  '';
in
{
  options.local.omarchy.keys = {
    shared = lib.mkOption { type = lib.types.listOf binding; default = [ ]; };
    extra = lib.mkOption { type = lib.types.listOf binding; default = [ ]; };
    external = lib.mkOption { type = lib.types.listOf external; default = [ ]; };
    unbind = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
    fragments = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
    workProfile = lib.mkOption { type = lib.types.str; };
    calendarCommand = lib.mkOption { type = lib.types.str; };
  };

  config = {
    home-manager.users.olafkfreund.home.file = {
      ".config/hypr/repo-keys.lua".text = repoLua;
      ".config/hypr/repo-keys.json".source = (pkgs.formats.json { }).generate "repo-keys.json" {
        inherit keys;
        inherit (cfg) external unbind;
      };
    };

    assertions = [
      {
        assertion = builtins.length chords == builtins.length (lib.unique chords);
        message = "local.omarchy.keys has duplicate chords in shared, extra or external";
      }
      {
        assertion = profile == null || (
          cfg.workProfile == "Profile ${profile}"
            && lib.hasInfix "Profile ${profile}" repoLua
            && lib.hasInfix "Profile_${profile}" repoLua
            && !lib.hasInfix "Profile ${otherProfile}" repoLua
            && !lib.hasInfix "Profile_${otherProfile}" repoLua
        );
        message = "local.omarchy.keys uses the wrong browser profile for ${config.networking.hostName}";
      }
    ];
  };
}
