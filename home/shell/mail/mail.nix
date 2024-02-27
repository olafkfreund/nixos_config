{ pkgs, pkgs-stable, ... }: {

home.packages = with pkgs; [
  mutt
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
  davmail
  python311Packages.vobject
  python311Packages.icalendar
  python311Packages.pytz
  python311Packages.tzlocal
  python311Packages.imaplib2
  ];
}