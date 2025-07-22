{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.features.email;
in {
  config = mkIf (cfg.enable && cfg.neomutt.enable) {
    # Gruvbox theme for NeoMutt
    environment.etc."neomutt/colors-gruvbox" = {
      text = ''
        # Gruvbox Dark Theme for NeoMutt
        # Matching existing system Gruvbox configuration
        
        # Basic colors
        color normal     color223 color235   # fg0/bg0
        color error      color167 color235   # red/bg0
        color tilde      color246 color235   # gray/bg0
        color message    color208 color235   # orange/bg0
        color markers    color243 color235   # gray/bg0
        color attachment color142 color235   # green/bg0
        color search     color235 color208   # bg0/orange
        
        # Sidebar colors
        color sidebar_divider    color246 color235   # gray/bg0
        color sidebar_flagged    color167 color235   # red/bg0
        color sidebar_highlight  color223 color237   # fg0/bg1
        color sidebar_indicator  color223 color142   # fg0/green
        color sidebar_new        color142 color235   # green/bg0
        color sidebar_ordinary   color246 color235   # gray/bg0
        color sidebar_spoolfile  color208 color235   # orange/bg0
        
        # Index colors
        color index      color246 color235 ".*"                        # default
        color index_date color246 color235 
        color index_flags color167 color235 "~F"                       # flagged
        color index_subject color223 color235 "~U"                     # unread
        color index_author color142 color235 "~U"                      # unread
        color index      color208 color235 "~T"                        # tagged
        color index      color167 color235 "~D"                        # deleted
        
        # Header colors
        color hdrdefault color246 color235
        color header     color208 color235 "^(From)"
        color header     color208 color235 "^(Subject)"
        color header     color142 color235 "^(Date)"
        color header     color142 color235 "^(To)"
        color header     color142 color235 "^(Cc)"
        
        # Body colors
        color quoted     color108 color235   # green
        color quoted1    color175 color235   # purple
        color quoted2    color250 color235   # fg2
        color quoted3    color108 color235   # green
        color quoted4    color175 color235   # purple
        
        # URL colors
        color body       color175 color235 "([a-z][a-z0-9+-]*://(((([a-z0-9_.!~*'();:&=+$,-]|%[0-9a-f][0-9a-f])*@)?((([a-z0-9]([a-z0-9-]*[a-z0-9])?)\\.)*([a-z]([a-z0-9-]*[a-z0-9])?)\\.?|[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+)(:[0-9]+)?)|([a-z0-9_.!~*'()$,;:@&=+-]|%[0-9a-f][0-9a-f])+)(/([a-z0-9_.!~*'():@&=+$,-]|%[0-9a-f][0-9a-f])*(;([a-z0-9_.!~*'():@&=+$,-]|%[0-9a-f][0-9a-f])*)*(/([a-z0-9_.!~*'():@&=+$,-]|%[0-9a-f][0-9a-f])*(;([a-z0-9_.!~*'():@&=+$,-]|%[0-9a-f][0-9a-f])*)*)*)?(\\?([a-z0-9_.!~*'();/?:@&=+$,-]|%[0-9a-f][0-9a-f])*)?(#([a-z0-9_.!~*'();/?:@&=+$,-]|%[0-9a-f][0-9a-f])*)?|(www|ftp)\\.(([a-z0-9]([a-z0-9-]*[a-z0-9])?)\\.)*([a-z]([a-z0-9-]*[a-z0-9])?)\\.?(:[0-9]+)?(/([-a-z0-9_.!~*'():@&=+$,]|%[0-9a-f][0-9a-f])*(;([-a-z0-9_.!~*'():@&=+$,]|%[0-9a-f][0-9a-f])*)*(/([-a-z0-9_.!~*'():@&=+$,]|%[0-9a-f][0-9a-f])*(;([-a-z0-9_.!~*'():@&=+$,]|%[0-9a-f][0-9a-f])*)*)*)?(\\?([-a-z0-9_.!~*'();/?:@&=+$,]|%[0-9a-f][0-9a-f])*)?(#([-a-z0-9_.!~*'();/?:@&=+$,]|%[0-9a-f][0-9a-f])*)?)"
        
        # Email addresses
        color body       color208 color235 "((@(([0-9a-z-]+\\.)*[0-9a-z-]+\\.?|#[0-9]+|\\[[0-9]?[0-9]?[0-9]\\.[0-9]?[0-9]?[0-9]\\.[0-9]?[0-9]?[0-9]\\.[0-9]?[0-9]?[0-9]\\]),)*@(([0-9a-z-]+\\.)*[0-9a-z-]+\\.?|#[0-9]+|\\[[0-9]?[0-9]?[0-9]\\.[0-9]?[0-9]?[0-9]\\.[0-9]?[0-9]?[0-9]\\.[0-9]?[0-9]?[0-9]\\]):)?[0-9a-z_.+%$-]+@(([0-9a-z-]+\\.)*[0-9a-z-]+\\.?|#[0-9]+|\\[[0-2]?[0-9]?[0-9]\\.[0-2]?[0-9]?[0-9]\\.[0-2]?[0-9]?[0-9]\\.[0-2]?[0-9]?[0-9]\\])"
        
        # Compose colors
        color compose header           color208 color235
        color compose security_encrypt color175 color235
        color compose security_sign    color142 color235
        color compose security_both    color174 color235
        color compose security_none    color246 color235
      '';
      mode = "0644";
    };
  };
}