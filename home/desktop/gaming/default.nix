{
  pkgs,
  pkgs-stable,
  ...
}: {
  home.packages = with pkgs; [
    moonlight-qt
    # moonlight-embedded
    looking-glass-client
  ];
}
