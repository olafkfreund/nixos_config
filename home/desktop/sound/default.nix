{pkgs, ...}: {
  home.packages = with pkgs; [
    qpaeq
    # gxmatcheq-lv2
    jamesdsp
    # fcast-client
    # fcast-receiver
  ];
}
