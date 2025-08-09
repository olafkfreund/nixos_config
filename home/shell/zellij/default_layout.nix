{ pkgs
, config
, ...
}: {
  xdg.configFile."zellij/layouts/default.kdl".text = ''
    layout {
        default_tab_template {
            pane size=2 borderless=true {
                plugin location="file://${pkgs.zjstatus}/bin/zjstatus.wasm" {
                    format_left   "{mode}#[bg=#${config.colorScheme.palette.base00}] {tabs}"
                    format_center ""
                    format_right  "#[bg=#${config.colorScheme.palette.base00},fg=#${config.colorScheme.palette.base0D}]#[bg=#${config.colorScheme.palette.base0D},fg=#${config.colorScheme.palette.base01},bold] #[bg=#${config.colorScheme.palette.base02},fg=#${config.colorScheme.palette.base05},bold] {session} #[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base05},bold]"
                    format_space  ""
                    format_hide_on_overlength "true"
                    format_precedence "crl"

                    border_enabled  "false"
                    border_char     "─"
                    border_format   "#[fg=#6C7086]{char}"
                    border_position "top"

                    mode_normal        "#[bg=#${config.colorScheme.palette.base0B},fg=#${config.colorScheme.palette.base02},bold] NORMAL#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base0B}]█"
                    mode_locked        "#[bg=#${config.colorScheme.palette.base04},fg=#${config.colorScheme.palette.base02},bold] LOCKED #[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base04}]█"
                    mode_resize        "#[bg=#${config.colorScheme.palette.base08},fg=#${config.colorScheme.palette.base02},bold] RESIZE#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base08}]█"
                    mode_pane          "#[bg=#${config.colorScheme.palette.base0D},fg=#${config.colorScheme.palette.base02},bold] PANE#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base0D}]█"
                    mode_tab           "#[bg=#${config.colorScheme.palette.base07},fg=#${config.colorScheme.palette.base02},bold] TAB#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base07}]█"
                    mode_scroll        "#[bg=#${config.colorScheme.palette.base0A},fg=#${config.colorScheme.palette.base02},bold] SCROLL#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base0A}]█"
                    mode_enter_search  "#[bg=#${config.colorScheme.palette.base0D},fg=#${config.colorScheme.palette.base02},bold] ENT-SEARCH#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base0D}]█"
                    mode_search        "#[bg=#${config.colorScheme.palette.base0D},fg=#${config.colorScheme.palette.base02},bold] SEARCHARCH#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base0D}]█"
                    mode_rename_tab    "#[bg=#${config.colorScheme.palette.base07},fg=#${config.colorScheme.palette.base02},bold] RENAME-TAB#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base07}]█"
                    mode_rename_pane   "#[bg=#${config.colorScheme.palette.base0D},fg=#${config.colorScheme.palette.base02},bold] RENAME-PANE#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base0D}]█"
                    mode_session       "#[bg=#${config.colorScheme.palette.base0E},fg=#${config.colorScheme.palette.base02},bold] SESSION#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base0E}]█"
                    mode_move          "#[bg=#${config.colorScheme.palette.base0F},fg=#${config.colorScheme.palette.base02},bold] MOVE#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base0F}]█"
                    mode_prompt        "#[bg=#${config.colorScheme.palette.base0D},fg=#${config.colorScheme.palette.base02},bold] PROMPT#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base0D}]█"
                    mode_tmux          "#[bg=#${config.colorScheme.palette.base09},fg=#${config.colorScheme.palette.base02},bold] TMUX#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base09}]█"

                    // formatting for inactive tabs
                    tab_normal              "#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base0D}]█#[bg=#${config.colorScheme.palette.base0D},fg=#${config.colorScheme.palette.base02},bold]{index} #[bg=#${config.colorScheme.palette.base02},fg=#${config.colorScheme.palette.base05},bold] {name}{floating_indicator}#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base02},bold]█"
                    tab_normal_fullscreen   "#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base0D}]█#[bg=#${config.colorScheme.palette.base0D},fg=#${config.colorScheme.palette.base02},bold]{index} #[bg=#${config.colorScheme.palette.base02},fg=#${config.colorScheme.palette.base05},bold] {name}{fullscreen_indicator}#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base02},bold]█"
                    tab_normal_sync         "#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base0D}]█#[bg=#${config.colorScheme.palette.base0D},fg=#${config.colorScheme.palette.base02},bold]{index} #[bg=#${config.colorScheme.palette.base02},fg=#${config.colorScheme.palette.base05},bold] {name}{sync_indicator}#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base02},bold]█"

                    // formatting for the current active tab
                    tab_active              "#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base09}]█#[bg=#${config.colorScheme.palette.base09},fg=#${config.colorScheme.palette.base02},bold]{index} #[bg=#${config.colorScheme.palette.base02},fg=#${config.colorScheme.palette.base05},bold] {name}{floating_indicator}#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base02},bold]█"
                    tab_active_fullscreen   "#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base09}]█#[bg=#${config.colorScheme.palette.base09},fg=#${config.colorScheme.palette.base02},bold]{index} #[bg=#${config.colorScheme.palette.base02},fg=#${config.colorScheme.palette.base05},bold] {name}{fullscreen_indicator}#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base02},bold]█"
                    tab_active_sync         "#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base09}]█#[bg=#${config.colorScheme.palette.base09},fg=#${config.colorScheme.palette.base02},bold]{index} #[bg=#${config.colorScheme.palette.base02},fg=#${config.colorScheme.palette.base05},bold] {name}{sync_indicator}#[bg=#${config.colorScheme.palette.base03},fg=#${config.colorScheme.palette.base02},bold]█"

                    // separator between the tabs
                    tab_separator           "#[bg=#${config.colorScheme.palette.base00}] "

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
