{ pkgs }:

pkgs.github-runner.overrideAttrs (old: {
  patches = old.patches ++ [ ./drain.patch ];
})
