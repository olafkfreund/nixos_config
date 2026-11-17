{ lib
, stdenvNoCC
, fetchFromGitHub
}:
# Shelfish (subculture-collective/omarchy-plugin-shelfish): groups Omarchy bar
# widgets into named shelves; only the open shelf's widgets are loaded.
# Bump against: gh api repos/subculture-collective/omarchy-plugin-shelfish/commits/main --jq .sha
stdenvNoCC.mkDerivation {
  pname = "shelfish";
  version = "1.1.1";

  src = fetchFromGitHub {
    owner = "subculture-collective";
    repo = "omarchy-plugin-shelfish";
    rev = "56f66d26c657a06d18a95c73031c0ec46735b285"; # main: has apply-layout.py, which this shell needs; the v1.1.1 tag predates it
    hash = "sha256-td+3MauwTflXuO/sz4Z2I64IWHWUsMso+VasY8LUjQE=";
  };

  dontBuild = true;

  # Its layout helper runs as `python3 apply-layout.py` from the shell, which
  # finds python3 on the system PATH; no patching needed.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/shelfish
    cp -r . $out/share/shelfish/plugin
    rm -rf $out/share/shelfish/plugin/{.gitea,.github,tests,docs}
    runHook postInstall
  '';

  meta = {
    description = "Omarchy bar plugin that groups widgets into named shelves";
    homepage = "https://github.com/subculture-collective/omarchy-plugin-shelfish";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
