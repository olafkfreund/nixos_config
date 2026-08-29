{ pkgs, ... }: {
  home.packages = with pkgs; [
    qpaeq
    # gxmatcheq-lv2
    # fcast-client
    # fcast-receiver
  ];
}
