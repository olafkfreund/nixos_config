# Enhanced Thunderbird Configuration with Stylix Theme Integration
#
# This configuration provides enterprise-grade security, privacy, and performance
# optimizations with comprehensive Stylix theming integration while maintaining
# compatibility with existing profiles and data.
#
# FEATURES IMPLEMENTED:
# - Phase 1: Security & Privacy (blocks tracking, disables telemetry)
# - Phase 2: GPG Integration (enables external GPG support)
# - Phase 3: Performance Optimization (database, network, UI tuning)
# - Phase 4: Stylix Theme Integration (complete visual consistency)
#
# STYLIX INTEGRATION:
# - Automatic color scheme synchronization with system theme
# - Font integration (sans-serif, monospace, serif)
# - Interface theming (toolbars, buttons, menus, tabs)
# - Content theming (messages, compose, address book)
# - CSS customization enabled for userChrome.css and userContent.css
#
# SAFETY: All settings are non-destructive and preserve existing:
# - Email accounts and authentication
# - Folder structure and organization
# - Profile data and customizations
# - Cached messages and attachments

{ config
, pkgs
, ...
}: {
  # Required packages for proper Thunderbird UI rendering
  home.packages = with pkgs; [
    # GTK theme integration
    gtk3
    gtk4
    gsettings-desktop-schemas
    gnome.adwaita-icon-theme
    gnome.gnome-themes-extra

    # Thunderbird tray integration
    birdtray
  ];

  programs.thunderbird = {
    enable = true;
    package = pkgs.thunderbird-latest-unwrapped;

    profiles.default = {
      settings = {
        # === STYLIX THEME INTEGRATION ===
        # Enable CSS customization for Stylix theming
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

        # === UI/Theme Settings (existing + enhanced) ===
        "widget.content.gtk-theme-override" = "Adwaita:dark";
        "ui.use-xim" = false;
        "widget.disable-native-theme-for-content" = true;
        "layout.css.devPixelsPerPx" = "1.0";
        "layers.acceleration.force-enabled" = true;

        # Force dark theme to match Stylix polarity
        "ui.systemUsesDarkTheme" = 1;

        # === PHASE 1: Security & Privacy Settings ===
        # Privacy Protection
        "privacy.donottrackheader.enabled" = true;
        "mailnews.message_display.disable_remote_image" = true;
        "mailnews.message_display.disable_remote_images" = true;
        "mail.collect_email_address_outgoing" = false;
        "mailnews.headers.showUserAgent" = false;
        "mailnews.headers.showOrganization" = false;

        # Disable Telemetry & Data Collection
        "datareporting.healthreport.uploadEnabled" = false;
        "datareporting.policy.dataSubmissionEnabled" = false;
        "toolkit.telemetry.enabled" = false;
        "toolkit.crashreporter.enabled" = false;
        "toolkit.telemetry.archive.enabled" = false;
        "toolkit.telemetry.bhrPing.enabled" = false;

        # Security Hardening
        "security.tls.hello_downgrade_check" = true;
        "security.tls.insecure_fallback_hosts" = "";
        "security.default_personal_cert" = "Ask Every Time";
        "mail.smime.encrypt_to_self" = true;

        # Tracking Protection
        "privacy.trackingprotection.enabled" = true;
        "privacy.trackingprotection.socialtracking.enabled" = true;
        "network.prefetch-next" = false;
        "network.dns.disablePrefetch" = true;
        "network.http.speculative-parallel-limit" = 0;

        # === PHASE 2: GPG/Encryption Integration ===
        # Enable external GPG for smartcard/hardware support
        "mail.openpgp.allow_external_gnupg" = true;

        # GPG Security Settings (conservative defaults)
        "mail.e2ee.auto_enable" = false; # Require explicit encryption choice
        "mail.e2ee.auto_disable" = false;
        "mail.openpgp.key_assistant.enable" = true;

        # S/MIME Configuration
        "mail.identity.default.encryptionpolicy" = 0; # Never encrypt by default

        # === PHASE 3: Performance Optimization ===
        # Database Performance
        "mail.db.idle_limit" = 30000000; # 30MB idle limit
        "mail.db.max_gloda_results_for_autocomplete" = 1000;
        "mailnews.database.global.indexer.enabled" = true;

        # Network Performance
        "mail.imap.chunk_size" = 65536; # 64KB chunks for IMAP
        "mail.imap.fetch_by_chunks" = true;
        "browser.cache.memory.capacity" = 65536; # 64MB memory cache

        # Background Operations
        "mail.background_task_interval" = 600; # 10 minutes
        "mailnews.auto_config_url" = "https://autoconfig.thunderbird.net/v1.1/";

        # UI Performance
        "mail.showCondensedAddresses" = true;
        "ui.prefersReducedMotion" = 1;
        "toolkit.cosmeticAnimations.enabled" = false;

        # Threading Performance
        "mailnews.thread_pane_column_unthreads" = false;
        "mail.threaded_pane_splitter.view" = 180;

        # === Additional Productivity Settings ===
        # Compose Window Enhancements
        "mail.compose.default_to_paragraph" = true;
        "mail.SpellCheckBeforeSend" = true;
        "mail.spellcheck.inline" = true;

        # Modern Authentication Support
        "mail.server.default.authMethod" = 10; # OAuth2 when available

        # Notification Settings
        "mail.biff.show_tray_icon" = true;
        "mail.biff.show_alert" = true;
      };

      # === STYLIX THEME INTEGRATION - Interface CSS ===
      userChrome = ''
        /* Thunderbird Stylix Theme Integration */
        /* Applies your system color scheme and fonts to Thunderbird interface */

        :root {
          /* Import Stylix colors */
          --stylix-base00: ${config.lib.stylix.colors.base00} !important; /* Dark background */
          --stylix-base01: ${config.lib.stylix.colors.base01} !important; /* Lighter background */
          --stylix-base02: ${config.lib.stylix.colors.base02} !important; /* Selection background */
          --stylix-base03: ${config.lib.stylix.colors.base03} !important; /* Comments/secondary */
          --stylix-base04: ${config.lib.stylix.colors.base04} !important; /* Foreground/secondary */
          --stylix-base05: ${config.lib.stylix.colors.base05} !important; /* Foreground/primary */
          --stylix-base06: ${config.lib.stylix.colors.base06} !important; /* Light foreground */
          --stylix-base07: ${config.lib.stylix.colors.base07} !important; /* Light background */
          --stylix-base08: ${config.lib.stylix.colors.base08} !important; /* Red/error */
          --stylix-base09: ${config.lib.stylix.colors.base09} !important; /* Orange/warning */
          --stylix-base0A: ${config.lib.stylix.colors.base0A} !important; /* Yellow */
          --stylix-base0B: ${config.lib.stylix.colors.base0B} !important; /* Green/success */
          --stylix-base0C: ${config.lib.stylix.colors.base0C} !important; /* Cyan/info */
          --stylix-base0D: ${config.lib.stylix.colors.base0D} !important; /* Blue/primary */
          --stylix-base0E: ${config.lib.stylix.colors.base0E} !important; /* Magenta/accent */
          --stylix-base0F: ${config.lib.stylix.colors.base0F} !important; /* Brown */

          /* Apply Stylix fonts */
          --stylix-font-mono: "${config.stylix.fonts.monospace.name}" !important;
          --stylix-font-sans: "${config.stylix.fonts.sansSerif.name}" !important;
          --stylix-font-serif: "${config.stylix.fonts.serif.name}" !important;

          /* Thunderbird theme variables using Stylix colors */
          --toolbar-bgcolor: var(--stylix-base00) !important;
          --toolbar-color: var(--stylix-base05) !important;
          --lwt-accent-color: var(--stylix-base01) !important;
          --lwt-text-color: var(--stylix-base05) !important;
          --lwt-sidebar-background-color: var(--stylix-base01) !important;
          --lwt-sidebar-text-color: var(--stylix-base05) !important;
          --arrowpanel-background: var(--stylix-base01) !important;
          --arrowpanel-color: var(--stylix-base05) !important;
          --panel-background: var(--stylix-base01) !important;
          --panel-color: var(--stylix-base05) !important;
        }

        /* Main interface theming */
        #messengerWindow {
          background-color: var(--stylix-base00) !important;
          color: var(--stylix-base05) !important;
          font-family: var(--stylix-font-sans) !important;
        }

        /* Toolbar styling */
        .toolbar-barclass,
        #toolbar-menubar,
        #mail-toolbar-menubar2,
        #tabbar-toolbar {
          background-color: var(--stylix-base01) !important;
          color: var(--stylix-base05) !important;
          border-color: var(--stylix-base02) !important;
        }

        /* Button theming */
        .toolbarbutton-1 {
          background-color: var(--stylix-base01) !important;
          color: var(--stylix-base05) !important;
          border: 1px solid var(--stylix-base02) !important;
        }

        .toolbarbutton-1:hover {
          background-color: var(--stylix-base02) !important;
          color: var(--stylix-base06) !important;
        }

        .toolbarbutton-1[checked="true"] {
          background-color: var(--stylix-base0D) !important;
          color: var(--stylix-base00) !important;
        }

        /* Folder tree styling */
        #folderTree {
          background-color: var(--stylix-base01) !important;
          color: var(--stylix-base05) !important;
          font-family: var(--stylix-font-sans) !important;
        }

        /* Message list styling */
        #threadTree {
          background-color: var(--stylix-base00) !important;
          color: var(--stylix-base05) !important;
          font-family: var(--stylix-font-sans) !important;
        }

        /* Selected items */
        treechildren::-moz-tree-row(selected, focus) {
          background-color: var(--stylix-base0D) !important;
          color: var(--stylix-base00) !important;
        }

        treechildren::-moz-tree-row(unread) {
          font-weight: bold !important;
          color: var(--stylix-base0A) !important;
        }

        /* Menu theming */
        menupopup,
        popup {
          background-color: var(--stylix-base01) !important;
          color: var(--stylix-base05) !important;
          border: 1px solid var(--stylix-base02) !important;
        }

        menuitem:hover {
          background-color: var(--stylix-base0D) !important;
          color: var(--stylix-base00) !important;
        }

        /* Tab styling */
        .tabmail-tab {
          background-color: var(--stylix-base01) !important;
          color: var(--stylix-base04) !important;
          border-color: var(--stylix-base02) !important;
        }

        .tabmail-tab[selected="true"] {
          background-color: var(--stylix-base00) !important;
          color: var(--stylix-base05) !important;
        }

        /* Status bar */
        #status-bar {
          background-color: var(--stylix-base01) !important;
          color: var(--stylix-base05) !important;
        }

        /* Search box */
        #searchInput,
        #qfb-qs-textbox {
          background-color: var(--stylix-base00) !important;
          color: var(--stylix-base05) !important;
          border: 1px solid var(--stylix-base02) !important;
        }

        /* Clean minimal appearance - hide single tab */
        .tabmail-tab[first-visible-tab="true"][last-visible-tab="true"] {
          display: none !important;
        }
      '';

      # === STYLIX THEME INTEGRATION - Content CSS ===
      userContent = ''
        /* Thunderbird Content Styling with Stylix Theme */
        /* Applies your color scheme to message content and compose windows */

        /* Message content styling */
        body {
          background-color: ${config.lib.stylix.colors.base00} !important;
          color: ${config.lib.stylix.colors.base05} !important;
          font-family: "${config.stylix.fonts.sansSerif.name}" !important;
          font-size: ${toString config.stylix.fonts.sizes.popups}px !important;
        }

        /* Code blocks and monospace text */
        code, pre, tt, .moz-text-monospace {
          font-family: "${config.stylix.fonts.monospace.name}" !important;
          background-color: ${config.lib.stylix.colors.base01} !important;
          color: ${config.lib.stylix.colors.base05} !important;
          border: 1px solid ${config.lib.stylix.colors.base02} !important;
          padding: 2px 4px !important;
          border-radius: 3px !important;
        }

        /* Links */
        a:link {
          color: ${config.lib.stylix.colors.base0D} !important;
        }

        a:visited {
          color: ${config.lib.stylix.colors.base0E} !important;
        }

        a:hover {
          color: ${config.lib.stylix.colors.base0C} !important;
        }

        /* Quoted text styling */
        blockquote {
          border-left: 3px solid ${config.lib.stylix.colors.base0D} !important;
          padding-left: 10px !important;
          margin-left: 5px !important;
          color: ${config.lib.stylix.colors.base04} !important;
          background-color: ${config.lib.stylix.colors.base01} !important;
        }

        /* Headers */
        h1, h2, h3, h4, h5, h6 {
          color: ${config.lib.stylix.colors.base0D} !important;
          font-family: "${config.stylix.fonts.sansSerif.name}" !important;
        }

        /* Scrollbars */
        ::-webkit-scrollbar {
          width: 8px !important;
          background-color: ${config.lib.stylix.colors.base01} !important;
        }

        ::-webkit-scrollbar-thumb {
          background-color: ${config.lib.stylix.colors.base03} !important;
          border-radius: 4px !important;
        }

        ::-webkit-scrollbar-thumb:hover {
          background-color: ${config.lib.stylix.colors.base04} !important;
        }

        /* Address book and compose window styling */
        .cardViewOuterContainer,
        .compose-container {
          background-color: ${config.lib.stylix.colors.base00} !important;
          color: ${config.lib.stylix.colors.base05} !important;
        }

        /* Input fields in compose */
        input, textarea, select {
          background-color: ${config.lib.stylix.colors.base01} !important;
          color: ${config.lib.stylix.colors.base05} !important;
          border: 1px solid ${config.lib.stylix.colors.base02} !important;
          font-family: "${config.stylix.fonts.sansSerif.name}" !important;
        }

        input:focus, textarea:focus, select:focus {
          border-color: ${config.lib.stylix.colors.base0D} !important;
          box-shadow: 0 0 3px ${config.lib.stylix.colors.base0D}40 !important;
        }
      '';
    };
  };

  # Environment variables to ensure proper GTK integration
  home.sessionVariables = {
    # Force consistent GTK theming
    GTK_THEME = "Adwaita:dark";

    # Use XDG directories for configuration
    XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";

    # Disable client-side decorations to prevent rendering issues
    GTK_CSD = "0";

    # Set consistent icon theme
    GTK_ICON_THEME = "Adwaita";
  };

  # Configure GTK settings explicitly
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita";
      package = pkgs.gnome.gnome-themes-extra;
    };
    iconTheme = {
      name = "Adwaita";
      package = pkgs.gnome.adwaita-icon-theme;
    };
  };

  # Enable D-Bus for proper integration
  services.dbus.enable = true;
}
