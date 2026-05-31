# Reddit on the desktop — declarative newsboat feeds + a TUI client + a GTK
# client. Read-only by design (post-2023 Reddit API meltdown killed most
# write/vote flows for third-party clients unless you wire your own OAuth
# app — not worth the maintenance burden for a feed reader).
#
# Imported from Users/olafkfreund/profile.nix, so this lands on razer + p620
# but NOT on p510 (which uses a different home profile composition).
{ pkgs, ... }:
{
  # newsboat — TUI RSS reader. Reddit serves RSS at <subreddit>/.rss, so
  # subscribing is just listing the URLs here. `tags` are used by newsboat's
  # filter view (press `t` then a tag name).
  programs.newsboat = {
    enable = true;
    autoReload = true;
    reloadTime = 30; # minutes
    urls = [
      { url = "https://www.reddit.com/r/NixOS/.rss"; tags = [ "reddit" "nix" ]; title = "r/NixOS"; }
      { url = "https://www.reddit.com/r/unixporn/.rss"; tags = [ "reddit" "ricing" ]; title = "r/unixporn"; }
      { url = "https://www.reddit.com/r/ClaudeAI/.rss"; tags = [ "reddit" "ai" ]; title = "r/ClaudeAI"; }
      { url = "https://www.reddit.com/r/ClaudeCode/.rss"; tags = [ "reddit" "ai" ]; title = "r/ClaudeCode"; }
      { url = "https://www.reddit.com/r/tui/.rss"; tags = [ "reddit" "tui" ]; title = "r/tui"; }
      { url = "https://www.reddit.com/r/gnome/.rss"; tags = [ "reddit" "desktop" ]; title = "r/gnome"; }
      { url = "https://www.reddit.com/r/linux/.rss"; tags = [ "reddit" "linux" ]; title = "r/linux"; }
    ];
    # Sensible defaults: open links in the user's preferred browser via
    # xdg-open, cache feeds for offline browsing, and skip the (admittedly
    # cute) startup splash so it shows the article list immediately.
    extraConfig = ''
      browser "xdg-open"
      auto-reload yes
      max-items 100
      show-read-feeds no
      show-read-articles no
      confirm-mark-feed-read no
      external-url-viewer "urlview"
      bind-key j down
      bind-key k up
      bind-key J next-feed
      bind-key K prev-feed
    '';
  };

  # Standalone clients alongside newsboat:
  #   - reddit-tui : modern Go-based read-only browser (uses public JSON)
  #   - headlines  : GTK4 / Libadwaita GUI client when you want a window
  home.packages = with pkgs; [
    reddit-tui
    headlines
  ];
}
