{ pkgs, ... }: {
  home.packages = with pkgs; [
    # kdePackages.kdeconnect-kde
    kdePackages.xdg-desktop-portal-kde
  ];
}
