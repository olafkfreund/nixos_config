{ lib
, stdenvNoCC
, fetchurl
, unzip
, glib
}:
stdenvNoCC.mkDerivation rec {
  pname = "gnome-ext-docker-manager";
  version = "1";
  uuid = "docker-manager@omerfarukgungor";

  src = fetchurl {
    url = "https://extensions.gnome.org/extension-data/docker-manageromerfarukgungor.v${version}.shell-extension.zip";
    sha256 = "1gfxxh4qvkf7cgljb0vfj6n10hbk45srlrlmbpic4ymbnkkj7prk";
  };

  nativeBuildInputs = [ unzip glib ];

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -d "$out/share/gnome-shell/extensions/${uuid}"
    unzip -q "$src" -d "$out/share/gnome-shell/extensions/${uuid}"
    if [ -d "$out/share/gnome-shell/extensions/${uuid}/schemas" ]; then
      glib-compile-schemas "$out/share/gnome-shell/extensions/${uuid}/schemas"
    fi
    runHook postInstall
  '';

  meta = with lib; {
    description = "Manage Docker containers from the GNOME top panel";
    homepage = "https://github.com/omerfarukgungor/docker-manager";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
