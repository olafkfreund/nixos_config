{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;
  inherit (config.lib.stylix) colors;
  cfg = config.features.email;
in
{
  config = mkIf (cfg.enable && cfg.neomutt.enable) {
    # Colours come from the active base16 scheme, like every other
    # surface. NeoMutt needs a truecolor build to honour #rrggbb.
    environment.etc."neomutt/colors-alien-hud" = {
      text = ''
        # Generated from assets/themes/alien-hud.yaml via Stylix

        # Basic colors
        color normal     #${colors.base05} #${colors.base00}   # fg0/bg0
        color error      #${colors.base08} #${colors.base00}   # red/bg0
        color tilde      #${colors.base04} #${colors.base00}   # gray/bg0
        color message    #${colors.base09} #${colors.base00}   # orange/bg0
        color markers    #${colors.base03} #${colors.base00}   # gray/bg0
        color attachment #${colors.base0B} #${colors.base00}   # green/bg0
        color search     #${colors.base00} #${colors.base09}   # bg0/orange

        # Sidebar colors
        color sidebar_divider    #${colors.base04} #${colors.base00}   # gray/bg0
        color sidebar_flagged    #${colors.base08} #${colors.base00}   # red/bg0
        color sidebar_highlight  #${colors.base05} #${colors.base01}   # fg0/bg1
        color sidebar_indicator  #${colors.base05} #${colors.base0B}   # fg0/green
        color sidebar_new        #${colors.base0B} #${colors.base00}   # green/bg0
        color sidebar_ordinary   #${colors.base04} #${colors.base00}   # gray/bg0
        color sidebar_spoolfile  #${colors.base09} #${colors.base00}   # orange/bg0

        # Index colors
        color index      #${colors.base04} #${colors.base00} ".*"                        # default
        color index_date #${colors.base04} #${colors.base00}
        color index_flags #${colors.base08} #${colors.base00} "~F"                       # flagged
        color index_subject #${colors.base05} #${colors.base00} "~U"                     # unread
        color index_author #${colors.base0B} #${colors.base00} "~U"                      # unread
        color index      #${colors.base09} #${colors.base00} "~T"                        # tagged
        color index      #${colors.base08} #${colors.base00} "~D"                        # deleted

        # Header colors
        color hdrdefault #${colors.base04} #${colors.base00}
        color header     #${colors.base09} #${colors.base00} "^(From)"
        color header     #${colors.base09} #${colors.base00} "^(Subject)"
        color header     #${colors.base0B} #${colors.base00} "^(Date)"
        color header     #${colors.base0B} #${colors.base00} "^(To)"
        color header     #${colors.base0B} #${colors.base00} "^(Cc)"

        # Body colors
        color quoted     #${colors.base0C} #${colors.base00}   # green
        color quoted1    #${colors.base0E} #${colors.base00}   # purple
        color quoted2    #${colors.base06} #${colors.base00}   # fg2
        color quoted3    #${colors.base0C} #${colors.base00}   # green
        color quoted4    #${colors.base0E} #${colors.base00}   # purple

        # URL colors
        color body       #${colors.base0E} #${colors.base00} "([a-z][a-z0-9+-]*://(((([a-z0-9_.!~*'();:&=+$,-]|%[0-9a-f][0-9a-f])*@)?((([a-z0-9]([a-z0-9-]*[a-z0-9])?)\\.)*([a-z]([a-z0-9-]*[a-z0-9])?)\\.?|[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+)(:[0-9]+)?)|([a-z0-9_.!~*'()$,;:@&=+-]|%[0-9a-f][0-9a-f])+)(/([a-z0-9_.!~*'():@&=+$,-]|%[0-9a-f][0-9a-f])*(;([a-z0-9_.!~*'():@&=+$,-]|%[0-9a-f][0-9a-f])*)*(/([a-z0-9_.!~*'():@&=+$,-]|%[0-9a-f][0-9a-f])*(;([a-z0-9_.!~*'():@&=+$,-]|%[0-9a-f][0-9a-f])*)*)*)?(\\?([a-z0-9_.!~*'();/?:@&=+$,-]|%[0-9a-f][0-9a-f])*)?(#([a-z0-9_.!~*'();/?:@&=+$,-]|%[0-9a-f][0-9a-f])*)?|(www|ftp)\\.(([a-z0-9]([a-z0-9-]*[a-z0-9])?)\\.)*([a-z]([a-z0-9-]*[a-z0-9])?)\\.?(:[0-9]+)?(/([-a-z0-9_.!~*'():@&=+$,]|%[0-9a-f][0-9a-f])*(;([-a-z0-9_.!~*'():@&=+$,]|%[0-9a-f][0-9a-f])*)*(/([-a-z0-9_.!~*'():@&=+$,]|%[0-9a-f][0-9a-f])*(;([-a-z0-9_.!~*'():@&=+$,]|%[0-9a-f][0-9a-f])*)*)*)?(\\?([-a-z0-9_.!~*'();/?:@&=+$,]|%[0-9a-f][0-9a-f])*)?(#([-a-z0-9_.!~*'();/?:@&=+$,]|%[0-9a-f][0-9a-f])*)?)"

        # Email addresses
        color body       #${colors.base09} #${colors.base00} "((@(([0-9a-z-]+\\.)*[0-9a-z-]+\\.?|#[0-9]+|\\[[0-9]?[0-9]?[0-9]\\.[0-9]?[0-9]?[0-9]\\.[0-9]?[0-9]?[0-9]\\.[0-9]?[0-9]?[0-9]\\]),)*@(([0-9a-z-]+\\.)*[0-9a-z-]+\\.?|#[0-9]+|\\[[0-9]?[0-9]?[0-9]\\.[0-9]?[0-9]?[0-9]\\.[0-9]?[0-9]?[0-9]\\.[0-9]?[0-9]?[0-9]\\]):)?[0-9a-z_.+%$-]+@(([0-9a-z-]+\\.)*[0-9a-z-]+\\.?|#[0-9]+|\\[[0-2]?[0-9]?[0-9]\\.[0-2]?[0-9]?[0-9]\\.[0-2]?[0-9]?[0-9]\\.[0-2]?[0-9]?[0-9]\\])"

        # Compose colors
        color compose header           #${colors.base09} #${colors.base00}
        color compose security_encrypt #${colors.base0E} #${colors.base00}
        color compose security_sign    #${colors.base0B} #${colors.base00}
        color compose security_both    #${colors.base0F} #${colors.base00}
        color compose security_none    #${colors.base04} #${colors.base00}
      '';
      mode = "0644";
    };
  };
}
