{ pkgs, ... }:
{
  home.packages = with pkgs; [
    goobook
    urlscan
    libnotify
    abook
    gcalcli
    # lbdb  # temporarily disabled: khard dep broken (sphinx-argparse vs Sphinx 9.x)
    python3Packages.vobject
    python3Packages.icalendar
    python3Packages.pytz
    python3Packages.tzlocal
    python3Packages.imaplib2
  ];
}
