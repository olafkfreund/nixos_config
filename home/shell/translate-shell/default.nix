{ pkgs, ... }:{
  home.packages = with pkgs; [ translate-shell ];
  xdg.configFile."translate-shell/init.trans".text = ''
    {
      :verbose         false
      :indent          2
      :hl              "no"
      :tl              ["en" "no"]
      :engine          "google"
      :theme           "random"
    }
  '';
}

