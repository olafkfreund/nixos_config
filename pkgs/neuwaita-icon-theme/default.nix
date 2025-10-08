{ lib
, stdenvNoCC
, fetchFromGitHub
}:

stdenvNoCC.mkDerivation rec {
  pname = "neuwaita-icon-theme";
  version = "unstable-2025-01-15";

  src = fetchFromGitHub {
    owner = "RusticBard";
    repo = "Neuwaita";
    rev = "4c63e30493ab34558539104309282877ab767798";
    hash = "sha256-NL8/ceugdGNSMpa8G/a4Eolutf5BcN6PXiQ9qDmHM1U=";
  };

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/icons/Neuwaita
    cp -r * $out/share/icons/Neuwaita/

    # Remove .git directory if it exists
    rm -rf $out/share/icons/Neuwaita/.git*

    runHook postInstall
  '';

  meta = with lib; {
    description = "A different take on the Adwaita icon theme";
    homepage = "https://github.com/RusticBard/Neuwaita";
    license = licenses.gpl3Plus; # Assuming GPL3+, verify from repository
    platforms = platforms.linux;
    maintainers = [ maintainers.olafkfreund or "olafkfreund" ];
  };
}
