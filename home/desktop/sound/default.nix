{ pkgs, ...}: {
  home.packages = with pkgs; [
    qpaeq
    pulseeffects-legacy
    gxmatcheq-lv2
    easyeffects
    jamesdsp
  ];
}
