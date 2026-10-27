{ lib
, stdenvNoCC
, fetchFromGitHub
, hyprland
, jq
, bash
}:
# Altscape (qempexe/omarchy-altscape): Alt+Tab window switcher for the Omarchy
# shell. hyprctl and bash are store paths. Upstream's bin/altscape-binds edits
# the user's Hyprland config at runtime; it is replaced by a status-only stub
# because NixOS owns the binds (hosts/common/nixos/omarchy-altscape.nix).
# Bump against: gh api repos/qempexe/omarchy-altscape/commits --jq '.[0].sha'
stdenvNoCC.mkDerivation {
  pname = "altscape-plugin";
  version = "1.0.2";

  src = fetchFromGitHub {
    owner = "qempexe";
    repo = "omarchy-altscape";
    rev = "3f99f8fd814b61261685865d55271670afb4b8e8";
    hash = "sha256-PVtoTZxtE9FhOpNymurlTQXzjB7tGqzu4DDWqecuUvk=";
  };

  dontBuild = true;

  postPatch = ''
    substituteInPlace qml/Service.qml \
      --replace-fail 'hyprctl -j clients' '${hyprland}/bin/hyprctl -j clients' \
      --replace-fail 'hyprctl -j workspaces' '${hyprland}/bin/hyprctl -j workspaces' \
      --replace-fail 'hyprctl -j monitors' '${hyprland}/bin/hyprctl -j monitors' \
      --replace-fail '["bash", root.bindHelper' '["${bash}/bin/bash", root.bindHelper'

    cp ${./altscape-binds-stub.sh} bin/altscape-binds
    chmod +x bin/altscape-binds
    substituteInPlace bin/altscape-binds \
      --subst-var-by hyprctl ${hyprland}/bin/hyprctl \
      --subst-var-by jq ${jq}/bin/jq
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r --no-preserve=mode . $out/
    rm -rf $out/screenshots $out/preview.png
    chmod +x $out/bin/altscape-binds

    runHook postInstall
  '';

  meta = {
    description = "Alt+Tab window switcher plugin for the Omarchy shell";
    homepage = "https://github.com/qempexe/omarchy-altscape";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
