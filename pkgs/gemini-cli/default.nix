{ lib
, fetchFromGitHub
, buildNpmPackage
, nodejs
, makeWrapper
, ...
}:
let
  version = "0.1.3-unstable-2025-06-25";
in
buildNpmPackage {
  pname = "gemini-cli";
  inherit version;

  src = fetchFromGitHub {
    owner = "google-gemini";
    repo = "gemini-cli";
    rev = "b6b9923dc3b80a73fdee3a3ccd6070c8cfb551cd"; # Latest commit as of 2025-06-25
    hash = "sha256-FJGj+R+s8A5Q8shkscAfqkqCLb+PafYiBYDjtoWqeMs=";
  };

  # This will be replaced with the correct hash after first build attempt
  npmDepsHash = "sha256-s1ULZUKwvB5Q5lnHz7U+EFd7ga+G22HVmwoRsneR+Lk=";

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ nodejs ];

  # The npm package.json has a "bundle" script that creates the final executable
  buildPhase = ''
    runHook preBuild

    # Generate git commit info (normally done by npm run generate)
    echo '{"version": "${version}", "commit": "nixpkgs-build"}' > git-commit-info.json

    # Build the bundle
    npm run bundle

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Create output directories
    mkdir -p $out/bin $out/lib/node_modules/@google/gemini-cli

    # Copy the bundled application
    cp -r bundle/* $out/lib/node_modules/@google/gemini-cli/

    # Create executable wrapper
    makeWrapper ${nodejs}/bin/node $out/bin/gemini \
      --add-flags "$out/lib/node_modules/@google/gemini-cli/gemini.js"

    runHook postInstall
  '';

  meta = {
    description = "Gemini CLI - A command-line AI workflow tool that connects to your tools, understands your code and accelerates your workflows";
    homepage = "https://github.com/google-gemini/gemini-cli";
    license = lib.licenses.asl20;
    maintainers = [ ]; # Add your maintainer info
    platforms = lib.platforms.all;
    mainProgram = "gemini";
  };
}
