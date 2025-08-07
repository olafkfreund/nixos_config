{ appimageTools
, fetchurl
, makeWrapper
,
}:
let
  pname = "msty";
  version = "1.7";
  src = fetchurl {
    url = "https://assets.msty.app/prod/latest/linux/rocm/Msty_x86_64_rocm.AppImage";
    sha256 = "sha256-82VCuwKwHF2CTdtf0GAUge+d4RyIGpd997chD/pCXYk=";
  };
  appimageContents = appimageTools.extractType2 { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  nativeBuildInputs = [ makeWrapper ];

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/msty.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/msty.desktop \
            --replace 'Exec=AppRun' 'Exec=${pname}'
    install -m 444 -D ${appimageContents}/msty.png \
            $out/share/icons/hicolor/256x256/apps/msty.png
    wrapProgram $out/bin/${pname} \
            --set XDG_CURRENT_DESKTOP GNOME
  '';
}
