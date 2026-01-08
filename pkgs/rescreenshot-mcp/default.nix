{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, openssl
, wayland
, libportal
, libsecret
, libxkbcommon
, libX11
, libxcb
, pipewire
, libGL
, mesa
, llvmPackages
, libgbm
}:

rustPlatform.buildRustPackage rec {
  pname = "rescreenshot-mcp";
  version = "0.6.0-unstable-2025-01-08";

  src = fetchFromGitHub {
    owner = "becksclair";
    repo = "rescreenshot-mcp";
    rev = "5c23e28613ac3f93b31038ca692510e7521f04a0";
    hash = "sha256-9sQEIXbI/27sudGLT8O1Tkw8lOx5o+VXbH4HrZBf4Kk=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  # Copy Cargo.lock into source since it's not committed to the repository
  postUnpack = ''
    cp ${./Cargo.lock} $sourceRoot/Cargo.lock
  '';

  nativeBuildInputs = [
    pkg-config
    llvmPackages.clang
  ];

  LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";

  buildInputs = [
    openssl
    wayland
    libportal
    libsecret
    libxkbcommon
    libX11
    libxcb
    pipewire
    libGL
    mesa
    libgbm
  ];

  # Disable tests that require keyring access (not available in Nix sandbox)
  doCheck = false;

  # Build only the MCP server binary
  cargoBuildFlags = [ "--package" "screenshot-mcp-server" ];

  # Install only the MCP server binary
  postInstall = ''
    mv $out/bin/screenshot-mcp $out/bin/rescreenshot-mcp
  '';

  meta = with lib; {
    description = "Cross-platform screenshot MCP server for Wayland, X11, and Windows";
    homepage = "https://github.com/becksclair/rescreenshot-mcp";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.linux;
    mainProgram = "rescreenshot-mcp";
  };
}
