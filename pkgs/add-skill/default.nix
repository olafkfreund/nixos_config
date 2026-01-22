{ lib
, buildNpmPackage
, fetchFromGitHub
}:

buildNpmPackage rec {
  pname = "add-skill";
  version = "1.0.22";

  src = fetchFromGitHub {
    owner = "vercel-labs";
    repo = "add-skill";
    rev = "75f142919d52a3ba88e852293803e1679041a938";
    hash = "sha256-Fh2c+Ctc/pbq8oH9lDbQLGcO34uvlEyOM2MZxso2O9o=";
  };

  npmDepsHash = "sha256-Wnbl7pNTyqHR4Xfhv4vAtusSY4yL2KdTLb9L/17d77o=";

  NODE_ENV = "development";
  NPM_CONFIG_INCLUDE = "dev";
  dontNpmPrune = true;
  npmInstallFlags = [ "--include=dev" ];

  # Force dev dependencies to be included in the cache
  npmDepsFlags = [ "--include=dev" ];

  makeCacheWritable = true;
  npmFlags = [ "--legacy-peer-deps" ];

  meta = with lib; {
    description = "CLI tool for installing skills from Git repositories to AI coding agents";
    homepage = "https://github.com/vercel-labs/add-skill";
    license = licenses.mit; # Assuming MIT, check repo
    maintainers = with maintainers; [ ];
    mainProgram = "add-skill";
    broken = true;
  };
}
