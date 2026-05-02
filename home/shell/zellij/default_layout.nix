{ pkgs
, config
, ...
}: {
  xdg.configFile."zellij/layouts/default.kdl".text = ''
    layout {
        default_tab_template {
            pane size=2 borderless=true {
                plugin location="file://${pkgs.zjstatus}/bin/zjstatus.wasm" {
                    format_left   "{mode}#[bg=#${config.lib.stylix.colors.base00}] {tabs}"
                    format_center ""
                    format_right  "#[bg=#${config.lib.stylix.colors.base00},fg=#${config.lib.stylix.colors.base0D}]#[bg=#${config.lib.stylix.colors.base0D},fg=#${config.lib.stylix.colors.base01},bold] #[bg=#${config.lib.stylix.colors.base02},fg=#${config.lib.stylix.colors.base05},bold] {session} #[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base05},bold]"
                    format_space  ""
                    format_hide_on_overlength "true"
                    format_precedence "crl"

                    border_enabled  "false"
                    border_char     "─"
                    border_format   "#[fg=#6C7086]{char}"
                    border_position "top"

                    mode_normal        "#[bg=#${config.lib.stylix.colors.base0B},fg=#${config.lib.stylix.colors.base02},bold] NORMAL#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base0B}]█"
                    mode_locked        "#[bg=#${config.lib.stylix.colors.base04},fg=#${config.lib.stylix.colors.base02},bold] LOCKED #[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base04}]█"
                    mode_resize        "#[bg=#${config.lib.stylix.colors.base08},fg=#${config.lib.stylix.colors.base02},bold] RESIZE#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base08}]█"
                    mode_pane          "#[bg=#${config.lib.stylix.colors.base0D},fg=#${config.lib.stylix.colors.base02},bold] PANE#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base0D}]█"
                    mode_tab           "#[bg=#${config.lib.stylix.colors.base07},fg=#${config.lib.stylix.colors.base02},bold] TAB#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base07}]█"
                    mode_scroll        "#[bg=#${config.lib.stylix.colors.base0A},fg=#${config.lib.stylix.colors.base02},bold] SCROLL#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base0A}]█"
                    mode_enter_search  "#[bg=#${config.lib.stylix.colors.base0D},fg=#${config.lib.stylix.colors.base02},bold] ENT-SEARCH#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base0D}]█"
                    mode_search        "#[bg=#${config.lib.stylix.colors.base0D},fg=#${config.lib.stylix.colors.base02},bold] SEARCHARCH#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base0D}]█"
                    mode_rename_tab    "#[bg=#${config.lib.stylix.colors.base07},fg=#${config.lib.stylix.colors.base02},bold] RENAME-TAB#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base07}]█"
                    mode_rename_pane   "#[bg=#${config.lib.stylix.colors.base0D},fg=#${config.lib.stylix.colors.base02},bold] RENAME-PANE#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base0D}]█"
                    mode_session       "#[bg=#${config.lib.stylix.colors.base0E},fg=#${config.lib.stylix.colors.base02},bold] SESSION#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base0E}]█"
                    mode_move          "#[bg=#${config.lib.stylix.colors.base0F},fg=#${config.lib.stylix.colors.base02},bold] MOVE#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base0F}]█"
                    mode_prompt        "#[bg=#${config.lib.stylix.colors.base0D},fg=#${config.lib.stylix.colors.base02},bold] PROMPT#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base0D}]█"
                    mode_tmux          "#[bg=#${config.lib.stylix.colors.base09},fg=#${config.lib.stylix.colors.base02},bold] TMUX#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base09}]█"

                    // formatting for inactive tabs
                    tab_normal              "#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base0D}]█#[bg=#${config.lib.stylix.colors.base0D},fg=#${config.lib.stylix.colors.base02},bold]{index} #[bg=#${config.lib.stylix.colors.base02},fg=#${config.lib.stylix.colors.base05},bold] {name}{floating_indicator}#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base02},bold]█"
                    tab_normal_fullscreen   "#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base0D}]█#[bg=#${config.lib.stylix.colors.base0D},fg=#${config.lib.stylix.colors.base02},bold]{index} #[bg=#${config.lib.stylix.colors.base02},fg=#${config.lib.stylix.colors.base05},bold] {name}{fullscreen_indicator}#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base02},bold]█"
                    tab_normal_sync         "#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base0D}]█#[bg=#${config.lib.stylix.colors.base0D},fg=#${config.lib.stylix.colors.base02},bold]{index} #[bg=#${config.lib.stylix.colors.base02},fg=#${config.lib.stylix.colors.base05},bold] {name}{sync_indicator}#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base02},bold]█"

                    // formatting for the current active tab
                    tab_active              "#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base09}]█#[bg=#${config.lib.stylix.colors.base09},fg=#${config.lib.stylix.colors.base02},bold]{index} #[bg=#${config.lib.stylix.colors.base02},fg=#${config.lib.stylix.colors.base05},bold] {name}{floating_indicator}#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base02},bold]█"
                    tab_active_fullscreen   "#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base09}]█#[bg=#${config.lib.stylix.colors.base09},fg=#${config.lib.stylix.colors.base02},bold]{index} #[bg=#${config.lib.stylix.colors.base02},fg=#${config.lib.stylix.colors.base05},bold] {name}{fullscreen_indicator}#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base02},bold]█"
                    tab_active_sync         "#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base09}]█#[bg=#${config.lib.stylix.colors.base09},fg=#${config.lib.stylix.colors.base02},bold]{index} #[bg=#${config.lib.stylix.colors.base02},fg=#${config.lib.stylix.colors.base05},bold] {name}{sync_indicator}#[bg=#${config.lib.stylix.colors.base03},fg=#${config.lib.stylix.colors.base02},bold]█"

                    // separator between the tabs
                    tab_separator           "#[bg=#${config.lib.stylix.colors.base00}] "

                    // indicators
                    tab_sync_indicator       " "
                    tab_fullscreen_indicator " 󰊓"
                    tab_floating_indicator   " 󰹙"

                    command_git_branch_command     "git rev-parse --abbrev-ref HEAD"
                    command_git_branch_format      "#[fg=blue] {stdout} "
                    command_git_branch_interval    "10"
                    command_git_branch_rendermode  "static"

                    datetime        "#[fg=#6C7086,bold] {format} "
                    datetime_format "%A, %d %b %Y %H:%M"
                    datetime_timezone "Europe/London"
                }
            }
            children
        }
    }
  '';
}
