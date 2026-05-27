# Reproducible MkDocs Material build of the repository documentation.
#
# Build with:  nix build .#docs   ->  ./result is the static site
# Preview with: nix develop .#docs ; mkdocs serve
#
# The source is filtered to only the inputs the site needs, so the huge
# assets/ tree and node_modules are never copied into the Nix store.
{ lib
, stdenvNoCC
, python3
,
}:
let
  pythonEnv = python3.withPackages (ps: [
    ps.mkdocs
    ps.mkdocs-material
    ps.mkdocs-gen-files
    ps.mkdocs-literate-nav
    ps.pymdown-extensions
  ]);

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../mkdocs.yml
      ../docs
      ../docs_gen
      ../modules
      ../pkgs
      ../hosts
      ../lib
      ../overlays
      ../README.md
    ];
  };
in
stdenvNoCC.mkDerivation {
  pname = "nixos-config-docs";
  version = "1.0.0";

  inherit src;

  nativeBuildInputs = [ pythonEnv ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    export HOME=$TMPDIR
    mkdocs build --site-dir $out
    runHook postBuild
  '';

  dontInstall = true;

  meta = {
    description = "MkDocs Material documentation site for the NixOS configuration";
    homepage = "https://olafkfreund.github.io/nixos_config/";
    platforms = lib.platforms.linux;
  };
}
