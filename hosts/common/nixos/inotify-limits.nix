_: {
  # Inotify limits — headroom for heavy multi-project dev (VSCode,
  # watchexec, multiple node_modules trees, file-watching dev servers).
  # Nixpkgs' sysctl.nix sets these to 524288 via mkDefault; we override
  # at normal priority for 4× margin across all hosts.
  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 2097152;
    "fs.inotify.max_user_instances" = 2097152;
    "fs.inotify.max_queued_events" = 2097152;
  };
}
