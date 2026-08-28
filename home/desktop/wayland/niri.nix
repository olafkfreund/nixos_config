{ config, lib, pkgs, osConfig, ... }:
# niri session: keybinds, layout, window rules and UK keyboard, hand-written
# into config.kdl because DankMaterialShell insists on that exact path.
let
  inherit (import ./common.nix { inherit pkgs osConfig; })
    wallpaper isLaptop geo gtkSchemas;
in
{


  # ── config.kdl is hand-written, not generated ──────────────────────────────
  # DankMaterialShell hardcodes ~/.config/niri/config.kdl as the file it inspects
  # (via `dms config resolve-include`) and rewrites (its "Fix Now" buttons), and
  # it IGNORES NIRI_CONFIG. So for DMS's include checks to pass — and for its
  # display / window-rule / cursor / keybind changes to actually persist —
  # config.kdl must BE the session's config, carrying the dms/*.kdl includes
  # DMS greps for.
  #
  # niri-flake always generates a config of its own from programs.niri.settings
  # and would write it to that same path, so it is retargeted out of the way.
  # Nothing loads the retargeted file; it exists only so the generator and the
  # hand-written config do not collide. This used to be config-noctalia.kdl,
  # loaded by a second "Niri" session running the Noctalia shell — that shell
  # was removed 2026-08-21 and with it every programs.niri.settings block that
  # fed this file.
  xdg.configFile.niri-config.target = lib.mkForce "niri/config-unused-generated.kdl";

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

    // Pin the internal panel to scale 1.0. DMS regenerates dms/outputs.kdl at
    // login and re-derives niri's auto scale (1.5) for the HiDPI eDP-1 panel,
    // undoing manual changes. This block sits after the DMS include and niri
    // uses the last output definition, so 1.0 wins on every reload. Harmless on
    // hosts without an eDP-1 (p620): niri ignores output blocks for absent outputs.
    output "eDP-1" {
        scale 1.0
    }

    input {
        keyboard {
            xkb { layout "gb"; }
            repeat-delay 600
            repeat-rate 25
        }
        touchpad { tap; natural-scroll; dwt; }
    }

    // HUD frame — kept byte-for-byte equivalent to the Noctalia session's
    // the DMS session.
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
        // Move the focused column to workspace N. The Hyprland session has had
        // these since #1367; niri only ever got the Page_Up/Down pair.
        Mod+Shift+1 { move-column-to-workspace 1; }
        Mod+Shift+2 { move-column-to-workspace 2; }
        Mod+Shift+3 { move-column-to-workspace 3; }
        Mod+Shift+4 { move-column-to-workspace 4; }
        Mod+Shift+5 { move-column-to-workspace 5; }
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
        // allow-when-locked mirrors the Hyprland session, where these carry
        // locked=true — volume and brightness should work on the lock screen.
        // -l 1 caps the sink at 100%, matching the Hyprland bind.
        XF86AudioRaiseVolume allow-when-locked=true { spawn "wpctl" "set-volume" "-l" "1" "@DEFAULT_AUDIO_SINK@" "5%+"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
        XF86AudioMute allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
        XF86AudioMicMute allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }
        XF86MonBrightnessUp allow-when-locked=true { spawn "brightnessctl" "set" "5%+"; }
        XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "set" "5%-"; }

        // Media transport. services.playerctld.enable is true on p620 and razer
        // and playerctl ships in modules/system-utils, but nothing was bound to
        // it in either session, so these keys did nothing.
        XF86AudioPlay allow-when-locked=true { spawn "playerctl" "play-pause"; }
        XF86AudioPause allow-when-locked=true { spawn "playerctl" "play-pause"; }
        XF86AudioNext allow-when-locked=true { spawn "playerctl" "next"; }
        XF86AudioPrev allow-when-locked=true { spawn "playerctl" "previous"; }
        XF86AudioStop allow-when-locked=true { spawn "playerctl" "stop"; }

        // Shell actions — DankMaterialShell (distinct from the Noctalia session,
        // (DMS IPC).
        Mod+D { spawn "dms" "ipc" "call" "spotlight" "toggle"; }
        Mod+Space { spawn "dms" "ipc" "call" "spotlight" "toggle"; }
        Mod+C { spawn "dms" "ipc" "call" "control-center" "toggle"; }
        Mod+N { spawn "dms" "ipc" "call" "notifications" "toggle"; }
        Mod+X { spawn "dms" "ipc" "call" "powermenu" "toggle"; }
        Mod+Backspace { spawn "dms" "ipc" "call" "lock" "lock"; }
        Mod+Shift+V { spawn "dms" "ipc" "call" "clipboard" "toggle"; }
    }

    // Start DMS (prefer the managed service; fall back to a direct spawn), plus
    // the same companion daemons as the Noctalia session. Idle lock uses DMS.
    spawn-at-startup "sh" "-c" "if systemctl --user start dms.service 2>/dev/null; then exit 0; fi; exec dms run"
    spawn-at-startup "swaybg" "-m" "fill" "-i" "${wallpaper}"
    spawn-at-startup "gammastep" "-l" "${geo}"
    spawn-at-startup "swayidle" "-w" "timeout" "300" "dms ipc call lock lock" "timeout" "600" "niri msg action power-off-monitors" "resume" "niri msg action power-on-monitors" ${lib.optionalString isLaptop ''"timeout" "1800" "systemctl suspend" ''}"before-sleep" "dms ipc call lock lock"
  '';

}
