{ lib
, buildNpmPackage
, fetchzip
, nix-update-script
,
}:
buildNpmPackage rec {
  pname = "github-copilot-cli";
  version = "1.0.56";

  src = fetchzip {
    url = "https://registry.npmjs.org/@github/copilot/-/copilot-${version}.tgz";
    hash = "sha256-xuBx4DZtuz9VsPLsjJHg2RVY+AEsdjUyQpHcHiolXuY=";
  };

  npmDepsHash = "sha256-QOrXq/+07uz5YgWrzeMw1eD1NESpmM6uiu9UW5Ld7qo=";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  passthru.updateScript = nix-update-script { extraArgs = [ "--generate-lockfile" ]; };

  meta = {
    description = "GitHub Copilot CLI brings the power of Copilot coding agent directly to your terminal";
    homepage = "https://github.com/github/copilot-cli";
    changelog = "https://github.com/github/copilot-cli/releases/tag/v${version}";
    downloadPage = "https://www.npmjs.com/package/@github/copilot";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [
      dbreyfogle
    ];
    mainProgram = "copilot";
  };
}
