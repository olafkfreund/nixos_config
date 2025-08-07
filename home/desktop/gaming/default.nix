{
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    moonlight-qt
    # moonlight-embedded
    looking-glass-client
  ];
}
