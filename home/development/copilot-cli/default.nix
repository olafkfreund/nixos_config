{ lib
, buildNpmPackage
, fetchzip
, nix-update-script
,
}:
buildNpmPackage rec {
  pname = "github-copilot-cli";
  version = "0.0.333";

  src = fetchzip {
    url = "https://registry.npmjs.org/@github/copilot/-/copilot-${version}.tgz";
    hash = "sha256-fq0oI8pcQJx87Dn+pCPNzffTW6xOArsMsbOhxS7wsLg=";
  };

  npmDepsHash = "sha256-/Cbo2M3xfNT10nd6SgKr+pn7t4w35lW6A5EleoadBEE=";

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
