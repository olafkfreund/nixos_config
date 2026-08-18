{ config, lib, pkgs, osConfig, ... }:
# niri session: keybinds, layout, window rules, UK keyboard, and the
# config.kdl / config-noctalia.kdl split that lets the Noctalia and DMS
# sessions share one compositor.
let
  inherit (import ./common.nix { inherit pkgs osConfig; })
    wallpaper isLaptop lockCmd geo gtkSchemas;
in
{
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
    GSETTINGS_SCHEMA_DIR = gtkSchemas;
  };

  # UK keyboard for the niri session (wlroots compositors don't inherit the
  # system xkb.layout).
  programs.niri.settings.input.keyboard.xkb.layout = "gb";

  # Layout: open windows full-width (niri's default is half) and draw a themed
  # hairline around EVERY window. Colours come from the Stylix base16 scheme
  # (alien-hud) so niri matches labwc/GNOME/tmux — active border = phosphor
  # green accent (base0B, same as labwc's window.active.border).
  #
  # HUD look: 1px lines rather than 2px slabs, and BOTH outlines on — niri draws
  # the focus-ring immediately outside the border, giving the double-rule frame
  # of the Weyland-Yutani plates. niri has no gap between the two rings and no
  # corner brackets, so this is as close as the compositor gets.
  programs.niri.settings.layout =
    let inherit (config.lib.stylix) colors; in {
      gaps = 12;
      background-color = "#${colors.base00}";
      default-column-width.proportion = 1.0;
      preset-column-widths = [
        { proportion = 0.5; }
        { proportion = 0.666667; }
        { proportion = 1.0; }
      ];

      # Inner rule: accent on focus, dim hairline otherwise.
      border = {
        enable = true;
        width = 1;
        active.color = "#${colors.base0B}";
        inactive.color = "#${colors.base03}";
      };

      # Outer rule, drawn just outside the border — the second line of the frame.
      focus-ring = {
        enable = true;
        width = 1;
        active.color = "#${colors.base03}";
        inactive.color = "#${colors.base01}";
      };

      # Phosphor bloom around the focused window. Offset 0/0 keeps it a halo
      # rather than a drop-shadow; the alpha suffix is the glow strength.
      shadow = {
        enable = true;
        softness = 14;
        spread = 0;
        offset = { x = 0; y = 0; };
        draw-behind-window = false;
        color = "#${colors.base0B}33";
        inactive-color = "#00000000";
      };
    };

  # Soft-rounded panel corners, matching the plates. clip-to-geometry rounds the
  # window surface itself, not just the decorations, so terminals don't poke
  # square corners through the frame.
  programs.niri.settings.window-rules = lib.mkAfter [
    {
      geometry-corner-radius = {
        top-left = 6.0;
        top-right = 6.0;
        bottom-right = 6.0;
        bottom-left = 6.0;
      };
      clip-to-geometry = true;
    }
  ];

  # Ask clients to drop their own (white) client-side decorations so niri draws
  # the themed server-side border instead. Without this, CSD apps like kitty
  # render a white titlebar *inside* niri's green border. labwc is unaffected
  # (its SSD titlebars are themed via themerc-override above).
  programs.niri.settings.prefer-no-csd = true;

  # Launch the shell + companion daemons at session start (inherit the niri
  # session env). swayidle works on niri (ext-idle-notify-v1): lock at 5 min,
  # monitors off at 10 min, and — laptops only — suspend at 30 min.
  programs.niri.settings.spawn-at-startup = lib.mkAfter [
    # Which shell launches is chosen by the login session: the stock "Niri"
    # session leaves DESK_SHELL unset → Noctalia; the "Niri (DankMaterialShell)"
    # session (modules/desktop/dms-shell.nix) sets DESK_SHELL="dms run" → DMS.
    { command = [ "sh" "-c" "exec \${DESK_SHELL:-noctalia}" ]; }
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

  # ── Session config split: DMS owns config.kdl, Noctalia moves aside ─────────
  # DankMaterialShell hardcodes ~/.config/niri/config.kdl as the file it inspects
  # (via `dms config resolve-include`) and rewrites (its "Fix Now" buttons), and
  # it IGNORES NIRI_CONFIG. So for DMS's include checks to pass — and for its
  # display / window-rule / cursor / keybind changes to actually persist —
  # config.kdl must BE the DMS session's config, carrying the dms/*.kdl includes
  # DMS greps for. We therefore retarget niri-flake's generated Noctalia config to
  # config-noctalia.kdl (the plain "Niri" session loads it via NIRI_CONFIG — see
  # modules/desktop/dms-shell.nix) and hand-write config.kdl as the DMS session's
  # config below. The two sessions then share NO niri settings: Noctalia never
  # sees dms/*.kdl and DMS never sees the Noctalia keybinds.
  xdg.configFile.niri-config.target = lib.mkForce "niri/config-noctalia.kdl";

  # config.kdl — the "Niri (DankMaterialShell)" session's config (dms-shell.nix
  # points that session here; it is also niri's default path, which is exactly
  # what DMS greps). Includes use niri's RELATIVE form `include "dms/…"`: current
  # niri resolves these against the config file's own directory (~/.config/niri),
  # so the store-symlinked config.kdl still finds the runtime dms/*.kdl fragments,
  # and the relative string is what DMS's resolve-include matches — clearing the
  # "… not included" banners. optional=true keeps niri happy before `dms setup`
  # has written a given fragment. The includes sit ABOVE the inline binds{} block,
  # so on any keybind conflict the inline scheme wins — keeping these keybinds
  # distinct from (and never leaking into) the Noctalia session.
  #
  # dms/colors.kdl and dms/layout.kdl are deliberately NOT included: both are
  # DMS's way of owning niri's `layout` node, and we own it here instead so the
  # DMS session gets the same HUD hairlines as the Noctalia one. niri rejects a
  # duplicate top-level `layout`, so including either alongside the block below
  # would break the session outright — which is also why colors.kdl is dropped
  # even though it is currently 0 bytes (it only gains a layout block if
  # enableDynamicTheming is ever flipped on in modules/desktop/dms-shell.nix).
  # Cost of this: DMS's gaps / corner-radius / border-size sliders become no-ops
  # for niri. Multiple `window-rule` nodes ARE legal, so dms/windowrules.kdl
  # still applies on top of ours.
  xdg.configFile."niri/config.kdl".text = ''
    include optional=true "dms/alttab.kdl"
    include optional=true "dms/wpblur.kdl"
    include optional=true "dms/outputs.kdl"
    include optional=true "dms/windowrules.kdl"
    include optional=true "dms/cursor.kdl"
    include optional=true "dms/binds.kdl"

    input {
        keyboard {
            xkb { layout "gb"; }
            repeat-delay 600
            repeat-rate 25
        }
        touchpad { tap; natural-scroll; dwt; }
    }

    // HUD frame — kept byte-for-byte equivalent to the Noctalia session's
    // programs.niri.settings.layout above, so both sessions look identical.
    layout {
        gaps 12
        background-color "#${config.lib.stylix.colors.base00}"
        default-column-width { proportion 1.0; }
        preset-column-widths {
            proportion 0.5
            proportion 0.666667
            proportion 1.0
        }
        border {
            width 1
            active-color "#${config.lib.stylix.colors.base0B}"
            inactive-color "#${config.lib.stylix.colors.base03}"
        }
        focus-ring {
            width 1
            active-color "#${config.lib.stylix.colors.base03}"
            inactive-color "#${config.lib.stylix.colors.base01}"
        }
        shadow {
            on
            softness 14
            spread 0
            offset x=0 y=0
            color "#${config.lib.stylix.colors.base0B}33"
            inactive-color "#00000000"
        }
    }

    window-rule {
        geometry-corner-radius 6
        clip-to-geometry true
    }

    prefer-no-csd
    screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"
    environment {
        "NIXOS_OZONE_WL" "1"
        "ELECTRON_OZONE_PLATFORM_HINT" "auto"
        "GSETTINGS_SCHEMA_DIR" "${gtkSchemas}"
        // DMS only recognises "gtk3"/"qt6ct" here (not the system-wide "qtct"),
        // so set qt6ct for this session — qt6ct-kde is installed, so Qt apps keep
        // their existing theming and DMS's "Missing Environment Variables" clears.
        "QT_QPA_PLATFORMTHEME" "qt6ct"
    }

    binds {
        // Window management — niri-native, shared with the Noctalia session.
        Mod+Return { spawn "ghostty"; }
        Mod+T { spawn "ghostty"; }
        Mod+E { spawn "nautilus"; }
        Mod+Q { close-window; }
        Mod+H { focus-column-left; }
        Mod+L { focus-column-right; }
        Mod+J { focus-window-down; }
        Mod+K { focus-window-up; }
        Mod+Left { focus-column-left; }
        Mod+Right { focus-column-right; }
        Mod+Down { focus-workspace-down; }
        Mod+Up { focus-workspace-up; }
        Mod+Shift+H { move-column-left; }
        Mod+Shift+L { move-column-right; }
        Mod+Shift+J { move-window-down; }
        Mod+Shift+K { move-window-up; }
        Mod+Shift+Left { move-column-left; }
        Mod+Shift+Right { move-column-right; }
        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }
        "Mod+Page_Down" { focus-workspace-down; }
        "Mod+Page_Up" { focus-workspace-up; }
        "Mod+Shift+Page_Down" { move-column-to-workspace-down; }
        "Mod+Shift+Page_Up" { move-column-to-workspace-up; }
        Mod+WheelScrollDown cooldown-ms=150 { focus-workspace-down; }
        Mod+WheelScrollUp cooldown-ms=150 { focus-workspace-up; }
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+Ctrl+Shift+F { toggle-windowed-fullscreen; }
        Mod+R { switch-preset-column-width; }
        Mod+Equal { set-column-width "+10%"; }
        Mod+Minus { set-column-width "-10%"; }
        Mod+Comma { consume-window-into-column; }
        Mod+Period { expel-window-from-column; }
        Mod+V { toggle-window-floating; }
        Mod+O { toggle-overview; }
        Mod+S { spawn "niri" "msg" "action" "screenshot"; }
        Mod+Ctrl+S { spawn "niri" "msg" "action" "screenshot-screen"; }
        Mod+Shift+S { spawn "niri" "msg" "action" "screenshot-window"; }
        Mod+Shift+R { spawn "screenrecord"; }
        Mod+Alt+R { spawn "screenrecord" "region"; }
        Mod+Shift+Slash { show-hotkey-overlay; }
        Mod+Shift+E { quit; }
        XF86AudioRaiseVolume { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
        XF86AudioLowerVolume { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
        XF86AudioMute { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
        XF86MonBrightnessUp { spawn "brightnessctl" "set" "5%+"; }
        XF86MonBrightnessDown { spawn "brightnessctl" "set" "5%-"; }

        // Shell actions — DankMaterialShell (distinct from the Noctalia session,
        // which uses `noctalia msg …` for these).
        Mod+D { spawn "dms" "ipc" "call" "spotlight" "toggle"; }
        Mod+Space { spawn "dms" "ipc" "call" "spotlight" "toggle"; }
        Mod+C { spawn "dms" "ipc" "call" "control-center" "toggle"; }
        Mod+N { spawn "dms" "ipc" "call" "notifications" "toggle"; }
        Mod+X { spawn "dms" "ipc" "call" "powermenu" "toggle"; }
        Mod+Backspace { spawn "dms" "ipc" "call" "lock" "lock"; }
    }

    // Start DMS (prefer the managed service; fall back to a direct spawn), plus
    // the same companion daemons as the Noctalia session. Idle lock uses DMS.
    spawn-at-startup "sh" "-c" "if systemctl --user start dms.service 2>/dev/null; then exit 0; fi; exec dms run"
    spawn-at-startup "swaybg" "-m" "fill" "-i" "${wallpaper}"
    spawn-at-startup "gammastep" "-l" "${geo}"
    spawn-at-startup "swayidle" "-w" "timeout" "300" "dms ipc call lock lock" "timeout" "600" "niri msg action power-off-monitors" "resume" "niri msg action power-on-monitors" ${lib.optionalString isLaptop ''"timeout" "1800" "systemctl suspend" ''}"before-sleep" "dms ipc call lock lock"
  '';

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
    "Mod+Shift+R".action = spawn "screenrecord";
    "Mod+Alt+R".action = spawn "screenrecord" "region";

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
}
