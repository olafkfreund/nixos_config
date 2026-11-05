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
    local.omarchy.keys =
      let
        profile = cfg.workProfile;
        profileClass = lib.replaceStrings [ " " ] [ "_" ] profile;
      in
      {
        shared = [
          {
            key = "SUPER + CTRL + M";
            description = "Gmail (freundcloud)";
            action = "omarchy-launch-or-focus \"chrome-fmgjjmmmlfnkbppncabfkddbjimcfncm-${profileClass}\" 'google-chrome-stable --profile-directory=\"${profile}\" --app-id=fmgjjmmmlfnkbppncabfkddbjimcfncm'";
          }
          {
            key = "SUPER + CTRL + SHIFT + M";
            description = "New email (freundcloud)";
            action = "gmail-compose-freundcloud \"${profile}\"";
          }
          {
            key = "SUPER + SHIFT + C";
            description = "Calendar (freundcloud)";
            action = cfg.calendarCommand;
          }
          {
            key = "SUPER + CTRL + J";
            description = "AI Kit";
            action = "aikit";
          }
          {
            key = "SUPER + CTRL + SHIFT + D";
            description = "New Google Doc (freundcloud)";
            action = "google-chrome-stable --profile-directory=\"${profile}\" --app=\"https://docs.new\"";
          }
          {
            key = "SUPER + CTRL + SHIFT + S";
            description = "New Google Sheet (freundcloud)";
            action = "google-chrome-stable --profile-directory=\"${profile}\" --app=\"https://sheets.new\"";
          }
          {
            key = "SUPER + CTRL + SHIFT + P";
            description = "New Google Slides (freundcloud)";
            action = "google-chrome-stable --profile-directory=\"${profile}\" --app=\"https://slides.new\"";
          }
          {
            key = "SUPER + SHIFT + S";
            description = "Google Maps";
            action = "omarchy-launch-or-focus \"chrome-maps\" \"omarchy-launch-webapp https://maps.google.com/\"";
          }
          {
            key = "SUPER + SHIFT + P";
            description = "Google Photos";
            action = "omarchy-launch-or-focus \"chrome-photos\" \"omarchy-launch-webapp https://photos.google.com/\"";
          }
          {
            key = "SUPER + SHIFT + CTRL + G";
            description = "Google Messages";
            action = "omarchy-launch-or-focus \"chrome-messages\" \"omarchy-launch-webapp https://messages.google.com/web/conversations\"";
          }
          {
            key = "SUPER + SHIFT + ALT + G";
            description = "WhatsApp";
            action = "omarchy-launch-or-focus \"chrome-web.whatsapp\" \"omarchy-launch-webapp https://web.whatsapp.com/\"";
          }
          {
            key = "SUPER + E";
            description = "Exposé";
            action = "hl.dsp.event(\"expose.window-overview:toggle\")";
            lua = true;
          }
          {
            key = "SUPER + H";
            description = "Nixi (nixarchy help)";
            action = "nixi";
          }
          {
            key = "SUPER + M";
            description = "Toggle voice control";
            action = "omarchy-voice listen toggle";
          }
          {
            key = "SUPER + N";
            description = "Minimize window to the dock";
            action = "omarchy-hyprland-window-minimize";
          }
          {
            key = "SUPER + SHIFT + H";
            description = "Herdr sessions menu";
            action = "omarchy-shell shell toggle nixarchy.herdr '{}'";
          }
          {
            key = "SUPER + ALT + A";
            description = "GitHub Actions";
            action = "python3 ~/.config/omarchy/plugins/olafkfreund.github-actions/menu.py toggle";
          }
          {
            key = "SUPER + CTRL + ALT + A";
            description = "GitHub Actions keybindings";
            action = "python3 ~/.config/omarchy/plugins/olafkfreund.github-actions/menu.py keys";
          }
          {
            key = "SUPER + ALT + P";
            description = "GitLab Pipelines";
            action = "python3 ~/.config/omarchy/plugins/olafkfreund.gitlab-pipelines/menu.py toggle";
          }
          {
            key = "SUPER + CTRL + ALT + P";
            description = "GitLab Pipelines keybindings";
            action = "python3 ~/.config/omarchy/plugins/olafkfreund.gitlab-pipelines/menu.py keys";
          }
          {
            key = "SUPER + ALT + B";
            description = "Bar settings";
            action = "omarchy-shell shell toggle skal.bar";
          }
          {
            key = "SUPER + ALT + Q";
            description = "Quick actions";
            action = "omarchy-shell -q skal.bar.controls toggle";
          }
          {
            key = "SUPER + ALT + N";
            description = "nixarchy packages";
            action = "omarchy-shell shell toggle nixarchy.pkg '{}'";
          }
          {
            key = "SUPER + ALT + E";
            description = "Dev environments";
            action = "nixarchy-plugin nixarchy.devenv";
          }
          {
            key = "SUPER + ALT + D";
            description = "Distrobox";
            action = "nixarchy-plugin nixarchy.distrobox";
          }
          {
            key = "SUPER + ALT + O";
            description = "Podman";
            action = "nixarchy-plugin nixarchy.podman";
          }
          {
            key = "SUPER + SHIFT + K";
            description = "OmaFob";
            action = "omarchy-shell yogeshojha.omafob toggle";
          }
        ];

        unbind = [
          "SUPER + SHIFT + E"
          "SUPER + SHIFT + ALT + E"
        ];

        fragments = [
          "hypr.gog-binds"
          "hypr.meet-binds"
          "hypr.ai-mirror-binds"
          "hypr.nixi-companion-binds"
          "hypr.microvm-binds"
          "hypr.plugin-browser-binds"
          "hypr.altscape-binds"
          "hypr.agent-voice-binds"
          "hypr.flea-binds"
        ];

        external = [
          {
            key = "SUPER + ALT + I";
            description = "Agent voice: tell me more";
          }
          {
            key = "SUPER + SHIFT + ALT + V";
            description = "Agent voice: toggle spoken summaries on/off";
          }
          {
            key = "SUPER + SHIFT + ESCAPE";
            description = "ai-mirror: stop agent control";
          }
          {
            key = "ALT + TAB";
            description = "Altscape: next window";
          }
          {
            key = "ALT + SHIFT + TAB";
            description = "Altscape: previous window";
          }
          {
            key = "SUPER + ALT + SHIFT + W";
            description = "Altscape settings";
          }
          {
            key = "SUPER + SHIFT + V";
            description = "New Google Meet (link copied)";
          }
          {
            key = "SUPER + CTRL + ALT + M";
            description = "Meeting record/transcribe/summarize";
          }
          {
            key = "SUPER + ALT + V";
            description = "MicroVMs";
          }
          {
            key = "SUPER + ALT + H";
            description = "Nixi companion: show or hide";
          }
          {
            key = "SUPER + ALT + SHIFT + S";
            description = "Nixi companion: listen";
          }
          {
            key = "SUPER + ALT + U";
            description = "Plugin browser";
          }
          {
            key = "SUPER + SHIFT + L";
            description = "Cycle workspace layout: scrolling, master, monocle";
          }
          {
            key = "SUPER + CTRL + SHIFT + L";
            description = "Layout: flip scrolling between horizontal and vertical";
          }
        ];
      };

    programs.nixarchy.menu.extraEntries = {
      "apps.distrobox" = {
        icon = "";
        label = "Distrobox";
        description = "Create, enter and manage containers · Super+Alt+D";
        aliases = [ "distrobox" "box" "boxes" "containers" ];
        action = "nixarchy-plugin nixarchy.distrobox";
      };
      "apps.podman" = {
        icon = "";
        label = "Podman";
        description = "Containers, images, volumes and networks · Super+Alt+O";
        aliases = [ "podman" "containers" "docker" "images" "volumes" "networks" ];
        action = "nixarchy-plugin nixarchy.podman";
      };
    };

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
