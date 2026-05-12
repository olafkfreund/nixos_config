{ lib
, stdenvNoCC
, fetchurl
, unzip
, glib
,
}:
stdenvNoCC.mkDerivation rec {
  pname = "aurora-shell";
  version = "49.2";

  uuid = "aurora-shell@luminusos.github.io";

  src = fetchurl {
    url = "https://github.com/luminusOS/aurora-shell/releases/download/v${version}/${uuid}.zip";
    # `name =` is required because the upstream filename contains '@',
    # which nix-prefetch-url and fetchurl reject by default.
    name = "${pname}-${version}.zip";
    hash = "sha256-GhknsZ6weF9EKNzKTluXdo6Gfxa/4By4GYYlyrpRPtU=";
  };

  nativeBuildInputs = [
    unzip
    glib
  ];

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -d "$out/share/gnome-shell/extensions/${uuid}"
    unzip -q "$src" -d "$out/share/gnome-shell/extensions/${uuid}"

    # Compile gschemas so GNOME's settings daemon can read the
    # module-toggle keys (`org.gnome.shell.extensions.aurora-shell`).
    if [ -d "$out/share/gnome-shell/extensions/${uuid}/schemas" ]; then
      glib-compile-schemas "$out/share/gnome-shell/extensions/${uuid}/schemas"
    fi

    runHook postInstall
  '';

  meta = with lib; {
    description = "Modular GNOME Shell extension with quality-of-life features (no-overview, pip-on-top, theme-changer, volume-mixer, …)";
    homepage = "https://github.com/luminusOS/aurora-shell";
    license = licenses.lgpl3Plus;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
