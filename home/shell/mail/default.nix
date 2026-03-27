{ pkgs, ... }:
{
  home.packages = with pkgs; [
    goobook
    urlscan
    libnotify
    abook
    gcalcli
    # lbdb  # temporarily disabled: khard dep broken (sphinx-argparse vs Sphinx 9.x)
    python312Packages.vobject
    python312Packages.icalendar
    python312Packages.pytz
    python312Packages.tzlocal
    python312Packages.imaplib2
  ];
}
