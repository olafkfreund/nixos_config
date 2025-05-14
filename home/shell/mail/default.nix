{pkgs, ...}: {
  home.packages = with pkgs; [
    mutt-ics
    mutt-wizard
    notmuch
    lieer
    neomutt
    goobook
    urlscan
    libnotify
    html2text
    isync
    msmtp
    openldap
    abook
    gcalcli
    lbdb
    python312Packages.vobject
    python312Packages.icalendar
    python312Packages.pytz
    python312Packages.tzlocal
    python312Packages.imaplib2
  ];
}
