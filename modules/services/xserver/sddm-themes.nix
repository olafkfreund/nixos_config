{ pkgs, stdenv, fetchFromGitHub, ... }:
{
  sddm-astronaut = stdenv.mkDerivation rec {
    pname = "sddm-astronaut-theme";
    version = "468a100460d5feaa701c2215c737b55789cba0fc";
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/share/sddm/themes
      cp -aR $src $out/share/sddm/themes/astronaut
    '';
    src = fetchFromGitHub {
      owner = "Keyitdev";
      repo = "sddm-astronaut-theme";
      rev = "${version}";
      sha256 = "1h20b7n6a4pbqnrj22y8v5gc01zxs58lck3bipmgkpyp52ip3vig";
    };
  };
  environment.systemPackages = with pkgs; [
    qt6.qtmultimedia
    libsForQt5.qt5.qtmultimedia
    libsForQt5.qt5.qtgraphicaleffects
    qt6.qtquick3d
    qt6.qtquicktimeline
    libsForQt5.qt5.qtquickcontrols
    qt6.qtquick3dphysics
    libsForQt5.qt5.qtquickcontrols2
    qt6.qtquickeffectmaker
    libsForQt5.sddm-kcm
    libsForQt5.phonon-backend-gstreamer
  ];
}
