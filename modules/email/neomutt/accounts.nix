{ config
, lib
, ...
}:
with lib; let
  cfg = config.features.email;
in
{
  config = mkIf (cfg.enable && cfg.neomutt.enable) {
    # Placeholder account configurations
    # These will be created as templates for now, actual OAuth2 setup comes later

    environment.etc."neomutt/accounts/freundcloud.template" = {
      text = ''
        # Account configuration for olaf@freundcloud.com
        # This is a template - actual credentials will be configured later

        set realname = "Olaf Freund"
        set from = "olaf@freundcloud.com"

        # IMAP settings (will be configured with OAuth2 later)
        set imap_user = "olaf@freundcloud.com"
        set folder = "imaps://imap.gmail.com:993/"
        set spoolfile = "+INBOX"
        set postponed = "+[Gmail]/Drafts"
        set record = "+[Gmail]/Sent Mail"
        set trash = "+[Gmail]/Trash"

        # SMTP settings (will be configured with OAuth2 later)
        set smtp_url = "smtps://olaf@freundcloud.com@smtp.gmail.com:465/"

        # Gmail-specific folders
        mailboxes "+INBOX" "+[Gmail]/Sent Mail" "+[Gmail]/Drafts" "+[Gmail]/Spam" "+[Gmail]/Trash" "+[Gmail]/All Mail"

        # Account-specific settings
        set signature = "~/.config/neomutt/signatures/freundcloud"
      '';
      mode = "0644";
    };

    environment.etc."neomutt/accounts/gmail.template" = {
      text = ''
        # Account configuration for olaf.loken@gmail.com
        # This is a template - actual credentials will be configured later

        set realname = "Olaf Loken"
        set from = "olaf.loken@gmail.com"

        # IMAP settings (will be configured with OAuth2 later)
        set imap_user = "olaf.loken@gmail.com"
        set folder = "imaps://imap.gmail.com:993/"
        set spoolfile = "+INBOX"
        set postponed = "+[Gmail]/Drafts"
        set record = "+[Gmail]/Sent Mail"
        set trash = "+[Gmail]/Trash"

        # SMTP settings (will be configured with OAuth2 later)
        set smtp_url = "smtps://olaf.loken@gmail.com@smtp.gmail.com:465/"

        # Gmail-specific folders
        mailboxes "+INBOX" "+[Gmail]/Sent Mail" "+[Gmail]/Drafts" "+[Gmail]/Spam" "+[Gmail]/Trash" "+[Gmail]/All Mail"

        # Account-specific settings
        set signature = "~/.config/neomutt/signatures/gmail"
      '';
      mode = "0644";
    };

    # Create basic signature templates
    environment.etc."neomutt/signatures/freundcloud.template" = {
      text = ''
        --
        Olaf Freund
        olaf@freundcloud.com
      '';
      mode = "0644";
    };

    environment.etc."neomutt/signatures/gmail.template" = {
      text = ''
        --
        Olaf Loken
        olaf.loken@gmail.com
      '';
      mode = "0644";
    };
  };
}
