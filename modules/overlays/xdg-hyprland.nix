final: prev:
{
  xdg-desktop-portal-hyprland = prev.xdg-desktop-portal-hyprland.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      (prev.fetchpatch {
      url = "https://github.com/hyprwm/xdg-desktop-portal-hyprland/commit/5555f467f68ce7cdf1060991c24263073b95e9da.patch";
      hash = "sha256-yNkg7GCXDPJdsE7M6J98YylnRxQWpcM5N3olix7Oc1A="; 
      })
      (prev.fetchpatch {
        url = "https://github.com/hyprwm/xdg-desktop-portal-hyprland/commit/0dd9af698b9386bcf25d3ea9f5017eca721831c1.patch";
      hash = "sha256-Y6eWASHoMXVN2rYJ1rs0jy2qP81/qbHsZU+6b7XNBBg=";
      })
      (prev.fetchpatch {
         url = "https://github.com/hyprwm/xdg-desktop-portal-hyprland/commit/2425e8f541525fa7409d9f26a8ffaf92a3767251.patch";
        hash = "sha256-6dCg/U/SIjtvo07Z3tn0Hn8Xwx72nwVz6Q2cFnObonU=";
      })
    ];
  });
}


