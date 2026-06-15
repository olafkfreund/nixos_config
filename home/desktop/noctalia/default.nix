{ config, lib, pkgs, osConfig, ... }:
# Noctalia desktop shell + niri/labwc session config (keybinds, layout, UK
# keyboard) for the niri and labwc sessions. Noctalia is launched only from the
# niri/labwc startup hooks (NOT via its systemd service, which binds to the
# graphical-session target that GNOME also reaches → would spawn a second shell
# over gnome-shell).
#
# Session companion tools (wallpaper, idle, night-light) follow the SAME rule:
# they are spawned from the niri/labwc startup hooks, never as systemd user
# services, so they don't also start under GNOME and fight its equivalents.
#
# Theming: builtin Catppuccin for now. TODO (fast-follow): bridge Stylix's
# base16 palette into programs.noctalia.customPalettes + theme.source="custom".
let
  # Wallpaper shared with Stylix (the system sets stylix.image to this same
  # path); swaybg paints it on the niri/labwc sessions, which Stylix does not.
  wallpaper = (import ../../../hosts/common/shared-variables.nix).baseTheme.wallpaper;

  # Only laptops auto-suspend on idle; the workstation stays up (RDP / AI host).
  isLaptop = (osConfig.host.class or "") == "laptop";

  # Reused for the idle lock action and the manual Mod+Backspace bind.
  lockCmd = "noctalia msg session lock";

  # Fixed UK coordinates (London) so gammastep adjusts colour temperature by
  # sun position without pulling in geoclue2.
  geo = "51.5:-0.13";
in
{
  # wl-mirror: mirror an output to a window (niri has no native mirroring).
  # jq: parse `niri msg --json`. wl-screenrec/slurp: HW-encoded screen recording.
  home.packages = with pkgs; [
    wl-mirror
    jq
    wl-screenrec
    slurp
    swaybg # static wallpaper for niri/labwc (Stylix only themes GNOME's bg)
    swayidle # idle → lock / screen-off / (laptop) suspend
    gammastep # night-light / colour temperature by sun position
    wlopm # labwc DPMS off/on (niri has a native power-off-monitors action)
    kanshi # output-profile daemon; per-host profiles are a TODO (niri does
    #         output config natively in config.kdl, so this is mainly for labwc)
    # Screen-recording toggle bound to Mod+Shift+R / Mod+Alt+R. Records the
    # focused output (or a slurp-selected region) to ~/Videos; re-run to stop.
    (writeShellScriptBin "niri-screenrecord" ''
      set -euo pipefail
      out="$HOME/Videos"; mkdir -p "$out"
      if ${procps}/bin/pgrep -x wl-screenrec >/dev/null 2>&1; then
        ${procps}/bin/pkill -INT -x wl-screenrec
        ${libnotify}/bin/notify-send "Screen recording" "Saved to $out"
      else
        f="$out/rec-$(date +%Y%m%d-%H%M%S).mp4"
        if [ "''${1:-}" = "region" ]; then
          geom="$(${slurp}/bin/slurp)" || exit 0
          ${wl-screenrec}/bin/wl-screenrec -g "$geom" -f "$f" &
        else
          name="$(${niri}/bin/niri msg --json focused-output | ${jq}/bin/jq -r .name)"
          ${wl-screenrec}/bin/wl-screenrec -o "$name" -f "$f" &
        fi
        ${libnotify}/bin/notify-send "Screen recording" "Recording… Mod+Shift+R to stop"
      fi
    '')
  ];

  programs.noctalia = {
    enable = true;
    systemd.enable = false;
    settings = {
      shell.font = "JetBrainsMono Nerd Font";
      # Enable the calendar service. The Google account + OAuth tokens are added
      # once via the GUI (Settings → Services → Calendar → Google) and stored in
      # the runtime state.toml — not here.
      calendar = {
        enabled = true;
        refresh_minutes = 15;
      };
      # Use the custom Gruvbox palette generated below (palettes/Gruvbox.json)
      # so the Noctalia shell matches Stylix/GNOME/tmux instead of Catppuccin.
      theme = {
        mode = "dark";
        source = "custom";
        custom_palette = "Gruvbox";
      };
    };
  };

  # Gruvbox palette for the Noctalia shell, derived from the Stylix base16
  # scheme so the bar/launcher/control-center match the rest of the system.
  # Selected via theme.source="custom" + custom_palette="Gruvbox" above.
  xdg.configFile."noctalia/palettes/Gruvbox.json".source =
    let
      inherit (config.lib.stylix) colors;
      c = n: "#${colors.${n}}";
      palette = {
        mPrimary = c "base0B"; # green accent (same as window borders)
        mOnPrimary = c "base00";
        mSecondary = c "base0D"; # blue
        mOnSecondary = c "base00";
        mTertiary = c "base0E"; # purple
        mOnTertiary = c "base00";
        mError = c "base08"; # red
        mOnError = c "base00";
        mSurface = c "base00"; # background
        mOnSurface = c "base05"; # foreground
        mSurfaceVariant = c "base01";
        mOnSurfaceVariant = c "base04";
        mOutline = c "base03";
        mShadow = c "base00";
        mHover = c "base02";
        mOnHover = c "base05";
        terminal = {
          background = c "base00";
          foreground = c "base05";
          cursor = c "base05";
          cursorText = c "base00";
          selectionBg = c "base02";
          selectionFg = c "base05";
          normal = {
            black = c "base01";
            red = c "base08";
            green = c "base0B";
            yellow = c "base0A";
            blue = c "base0D";
            magenta = c "base0E";
            cyan = c "base0C";
            white = c "base05";
          };
          bright = {
            black = c "base03";
            red = c "base08";
            green = c "base0B";
            yellow = c "base0A";
            blue = c "base0D";
            magenta = c "base0E";
            cyan = c "base0C";
            white = c "base07";
          };
        };
      };
    in
    (pkgs.formats.json { }).generate "Gruvbox.json" {
      dark = palette;
      light = palette;
    };

  # ── niri ───────────────────────────────────────────────────────────────
  # Session environment for everything niri spawns. NIXOS_OZONE_WL=1 makes
  # Electron apps (claude-desktop, VS Code, …) use the Wayland backend instead
  # of falling back to XWayland. The system sets this in environment.session-
  # Variables, but greetd launches `exec niri` without a login shell, so those
  # never reach the session — niri's own environment block is what propagates
  # it to child processes here.
  programs.niri.settings.environment = {
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
  };

  # UK keyboard for the niri session (wlroots compositors don't inherit the
  # system xkb.layout).
  programs.niri.settings.input.keyboard.xkb.layout = "gb";

  # Layout: open windows full-width (niri's default is half) and draw a themed
  # border around EVERY window. Colours come from the Stylix base16 scheme
  # (gruvbox-dark) so niri matches labwc/GNOME/tmux — active border = accent
  # (base0B, same as labwc's window.active.border), inactive = dim (base01).
  programs.niri.settings.layout =
    let inherit (config.lib.stylix) colors; in {
      gaps = 4;
      default-column-width.proportion = 1.0;
      preset-column-widths = [
        { proportion = 0.5; }
        { proportion = 0.666667; }
        { proportion = 1.0; }
      ];

      border = {
        enable = true;
        width = 2;
        active.color = "#${colors.base0B}";
        inactive.color = "#${colors.base01}";
      };

      # One outline only: the per-window border replaces niri's focus-ring.
      focus-ring.enable = false;
    };

  # Ask clients to drop their own (white) client-side decorations so niri draws
  # the themed server-side border instead. Without this, CSD apps like kitty
  # render a white titlebar *inside* niri's green border. labwc is unaffected
  # (its SSD titlebars are themed via themerc-override above).
  programs.niri.settings.prefer-no-csd = true;

  # Launch the shell + companion daemons at session start (inherit the niri
  # session env). swayidle works on niri (ext-idle-notify-v1): lock at 5 min,
  # monitors off at 10 min, and — laptops only — suspend at 30 min.
  programs.niri.settings.spawn-at-startup = lib.mkAfter [
    { command = [ "noctalia" ]; }
    { command = [ "swaybg" "-m" "fill" "-i" "${wallpaper}" ]; }
    { command = [ "gammastep" "-l" geo ]; }
    {
      command = [
        "swayidle"
        "-w"
        "timeout"
        "300"
        lockCmd
        "timeout"
        "600"
        "niri msg action power-off-monitors"
        "resume"
        "niri msg action power-on-monitors"
      ]
      ++ lib.optionals isLaptop [ "timeout" "1800" "systemctl suspend" ]
      ++ [ "before-sleep" lockCmd ];
    }
  ];

  # Keybinds. Mod = Super/logo. Press Mod+Shift+/ for niri's hotkey overlay.
  programs.niri.settings.binds = with config.lib.niri.actions; {
    "Mod+Return".action = spawn "ghostty";
    "Mod+T".action = spawn "ghostty";
    "Mod+D".action = spawn "noctalia" "msg" "panel-toggle" "launcher";
    "Mod+Space".action = spawn "noctalia" "msg" "panel-toggle" "launcher";
    "Mod+C".action = spawn "noctalia" "msg" "panel-toggle" "control-center";
    "Mod+Backspace".action = spawn "noctalia" "msg" "session" "lock";
    "Mod+E".action = spawn "nautilus";
    "Mod+Q".action = close-window;
    "Mod+Shift+E".action = quit; # niri asks for confirmation

    # Focus (arrows + vim hjkl)
    # Super+Left/Right = move between columns; Super+Up/Down = switch workspace.
    "Mod+Left".action = focus-column-left;
    "Mod+Right".action = focus-column-right;
    "Mod+Up".action = focus-workspace-up;
    "Mod+Down".action = focus-workspace-down;
    # vim keys: h/l columns, j/k window-within-column
    "Mod+H".action = focus-column-left;
    "Mod+L".action = focus-column-right;
    "Mod+J".action = focus-window-down;
    "Mod+K".action = focus-window-up;

    # Move
    "Mod+Shift+Left".action = move-column-left;
    "Mod+Shift+Right".action = move-column-right;
    "Mod+Shift+H".action = move-column-left;
    "Mod+Shift+L".action = move-column-right;
    "Mod+Shift+J".action = move-window-down;
    "Mod+Shift+K".action = move-window-up;

    # Workspaces (niri uses dynamic workspaces; focus by index, move relative)
    "Mod+1".action = focus-workspace 1;
    "Mod+2".action = focus-workspace 2;
    "Mod+3".action = focus-workspace 3;
    "Mod+4".action = focus-workspace 4;
    "Mod+5".action = focus-workspace 5;
    "Mod+Page_Down".action = focus-workspace-down;
    "Mod+Page_Up".action = focus-workspace-up;
    "Mod+Shift+Page_Down".action = move-column-to-workspace-down;
    "Mod+Shift+Page_Up".action = move-column-to-workspace-up;

    # Window/column sizing & state
    "Mod+F".action = maximize-column;
    "Mod+Shift+F".action = fullscreen-window;
    # Windowed/"fake" fullscreen: tells the app it's fullscreen while keeping it
    # a normal resizable window. Great for Google Slides / browser presentations.
    "Mod+Ctrl+Shift+F".action = toggle-windowed-fullscreen;
    "Mod+R".action = switch-preset-column-width;
    "Mod+V".action = toggle-window-floating;
    "Mod+Comma".action = consume-window-into-column;
    "Mod+Period".action = expel-window-from-column;
    # Overview (zoomed-out workspace/column view) — great for many editors open.
    "Mod+O".action = toggle-overview;
    # Fine column-width nudge.
    "Mod+Minus".action = set-column-width "-10%";
    "Mod+Equal".action = set-column-width "+10%";
    # Mouse: Mod+scroll switches workspaces (cooldown avoids over-scrolling).
    "Mod+WheelScrollDown" = { cooldown-ms = 150; action = focus-workspace-down; };
    "Mod+WheelScrollUp" = { cooldown-ms = 150; action = focus-workspace-up; };

    # Screenshots — this keyboard has NO Print key, so everything is Mod-based.
    # Saved to ~/Pictures/Screenshots/ AND the clipboard.
    "Mod+S".action = spawn "niri" "msg" "action" "screenshot"; # interactive picker (region/window/output)
    "Mod+Shift+S".action = spawn "niri" "msg" "action" "screenshot-window"; # focused window
    "Mod+Ctrl+S".action = spawn "niri" "msg" "action" "screenshot-screen"; # whole focused output
    "Mod+Shift+Slash".action = show-hotkey-overlay;

    # Screen recording (wl-screenrec, hardware-encoded) → ~/Videos. Re-press to
    # stop. Mod+Shift+R = focused output; Mod+Alt+R = slurp-selected region.
    "Mod+Shift+R".action = spawn "niri-screenrecord";
    "Mod+Alt+R".action = spawn "niri-screenrecord" "region";

    # Screen mirroring (wl-mirror): mirror the focused output into a window.
    # Move that window to the target output and Mod+Shift+F it to fullscreen.
    "Mod+P" = {
      repeat = false;
      action = spawn-sh "wl-mirror \"$(niri msg --json focused-output | jq -r .name)\"";
    };

    # Media / brightness keys
    "XF86AudioRaiseVolume".action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+";
    "XF86AudioLowerVolume".action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-";
    "XF86AudioMute".action = spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle";
    "XF86MonBrightnessUp".action = spawn "brightnessctl" "set" "5%+";
    "XF86MonBrightnessDown".action = spawn "brightnessctl" "set" "5%-";
  };

  # ── labwc ──────────────────────────────────────────────────────────────
  # Launch the shell + companion daemons from labwc's autostart hook. labwc has
  # no native DPMS action, so swayidle drives wlopm for screen-off. Same idle
  # timings as niri; suspend only on laptops.
  xdg.configFile."labwc/autostart".text = ''
    swaybg -m fill -i ${wallpaper} &
    gammastep -l ${geo} &
    swayidle -w \
      timeout 300 '${lockCmd}' \
      timeout 600 "wlopm --off '*'" resume "wlopm --on '*'" \
      ${lib.optionalString isLaptop "timeout 1800 'systemctl suspend' \\\n      "}before-sleep '${lockCmd}' &
    noctalia &
  '';

  # Session environment, read at labwc startup. XKB layout for the keyboard,
  # plus NIXOS_OZONE_WL=1 so Electron apps (claude-desktop, VS Code, …) use the
  # Wayland backend rather than XWayland — greetd's `exec labwc` doesn't source
  # the system environment.sessionVariables, so labwc exports them from here.
  xdg.configFile."labwc/environment".text = ''
    XKB_DEFAULT_LAYOUT=gb
    NIXOS_OZONE_WL=1
    ELECTRON_OZONE_PLATFORM_HINT=auto
  '';

  # Gruvbox-dark theming for labwc's OSD (window-switcher / workspace overlays
  # are white by default), window borders, and menus. themerc-override patches
  # the active theme's colors without needing a full theme. Colors come from
  # the system Stylix base16 scheme (gruvbox-dark), so this matches GNOME/tmux.
  xdg.configFile."labwc/themerc-override".text =
    let inherit (config.lib.stylix) colors; in ''
      # Window decorations
      window.active.border.color: #${colors.base0B}
      window.active.title.bg.color: #${colors.base00}
      window.active.label.text.color: #${colors.base05}
      window.inactive.border.color: #${colors.base01}
      window.inactive.title.bg.color: #${colors.base01}
      window.inactive.label.text.color: #${colors.base04}

      # Right-click / client menus
      menu.items.bg.color: #${colors.base00}
      menu.items.text.color: #${colors.base05}
      menu.items.active.bg.color: #${colors.base02}
      menu.items.active.text.color: #${colors.base05}

      # OSD overlays (the white window-switcher / workspace popups)
      osd.bg.color: #${colors.base00}
      osd.border.color: #${colors.base0B}
      osd.border.width: 2
      osd.label.text.color: #${colors.base05}
      osd.window-switcher.item.active.border.color: #${colors.base0B}
      osd.workspace-switcher.boxes.active.bg.color: #${colors.base0B}
      osd.workspace-switcher.boxes.inactive.bg.color: #${colors.base02}
    '';

  # Keybinds (labwc ships only sparse compiled-in defaults). W = Super/logo.
  xdg.configFile."labwc/rc.xml".text = ''
    <?xml version="1.0"?>
    <labwc_config>
      <desktops>
        <number>4</number>
      </desktops>
      <keyboard>
        <keybind key="W-Return"><action name="Execute" command="ghostty"/></keybind>
        <keybind key="W-d"><action name="Execute" command="noctalia msg panel-toggle launcher"/></keybind>
        <keybind key="W-c"><action name="Execute" command="noctalia msg panel-toggle control-center"/></keybind>
        <keybind key="W-BackSpace"><action name="Execute" command="noctalia msg session lock"/></keybind>
        <keybind key="Print"><action name="Execute" command="noctalia msg screenshot-region"/></keybind>
        <!-- Region screen recording (re-press to stop). niri-screenrecord's
             region branch is compositor-agnostic (slurp + wl-screenrec). -->
        <keybind key="W-S-r"><action name="Execute" command="niri-screenrecord region"/></keybind>
        <keybind key="W-e"><action name="Execute" command="nautilus"/></keybind>
        <keybind key="W-q"><action name="Close"/></keybind>
        <keybind key="A-Tab"><action name="NextWindow"/></keybind>
        <keybind key="A-S-Tab"><action name="PreviousWindow"/></keybind>
        <keybind key="W-f"><action name="ToggleMaximize"/></keybind>
        <keybind key="W-S-f"><action name="ToggleFullscreen"/></keybind>
        <keybind key="W-Space"><action name="ShowMenu" menu="client-menu"/></keybind>
        <keybind key="W-Left"><action name="GoToDesktop" to="left" wrap="yes"/></keybind>
        <keybind key="W-Right"><action name="GoToDesktop" to="right" wrap="yes"/></keybind>
        <keybind key="W-Up"><action name="GoToDesktop" to="left" wrap="yes"/></keybind>
        <keybind key="W-Down"><action name="GoToDesktop" to="right" wrap="yes"/></keybind>
        <keybind key="W-1"><action name="GoToDesktop" to="1"/></keybind>
        <keybind key="W-2"><action name="GoToDesktop" to="2"/></keybind>
        <keybind key="W-3"><action name="GoToDesktop" to="3"/></keybind>
        <keybind key="W-4"><action name="GoToDesktop" to="4"/></keybind>
        <keybind key="W-S-1"><action name="SendToDesktop" to="1"/></keybind>
        <keybind key="W-S-2"><action name="SendToDesktop" to="2"/></keybind>
        <keybind key="W-S-3"><action name="SendToDesktop" to="3"/></keybind>
        <keybind key="W-S-4"><action name="SendToDesktop" to="4"/></keybind>
        <keybind key="W-S-e"><action name="Exit"/></keybind>
        <keybind key="XF86_AudioRaiseVolume"><action name="Execute" command="wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"/></keybind>
        <keybind key="XF86_AudioLowerVolume"><action name="Execute" command="wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"/></keybind>
        <keybind key="XF86_AudioMute"><action name="Execute" command="wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"/></keybind>
        <keybind key="XF86_MonBrightnessUp"><action name="Execute" command="brightnessctl set 5%+"/></keybind>
        <keybind key="XF86_MonBrightnessDown"><action name="Execute" command="brightnessctl set 5%-"/></keybind>
      </keyboard>
    </labwc_config>
  '';
}
