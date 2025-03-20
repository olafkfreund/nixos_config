{
  lib,
  stdenv,
  python3,
  zlib,
  libffi,
  makeWrapper,
}: let
  pythonEnv = python3.withPackages (ps:
    with ps; [
      pip
      virtualenv
    ]);
in
  stdenv.mkDerivation rec {
    pname = "aider-chat-env";
    version = "0.1.0";

    src = ./.;

    nativeBuildInputs = [makeWrapper];
    buildInputs = [pythonEnv zlib libffi];

    installPhase = ''
      mkdir -p $out/bin
      cat > $out/bin/aider-chat-env <<EOF
      #!/bin/sh
      VENV_DIR="\$HOME/.aider-chat-venv"
      if [ ! -d "\$VENV_DIR" ]; then
        echo "Creating new virtual environment in \$VENV_DIR..."
        ${pythonEnv}/bin/python -m venv "\$VENV_DIR"
        source "\$VENV_DIR/bin/activate"
        # Upgrade pip first
        python -m pip install --no-cache-dir --upgrade pip
        # Install aider-chat
        python -m pip install --no-cache-dir aider-chat
      else
        source "\$VENV_DIR/bin/activate"
      fi
      exec "\$SHELL"
      EOF
      chmod +x $out/bin/aider-chat-env
    '';

    postFixup = ''
      wrapProgram $out/bin/aider-chat-env \
        --prefix PATH : ${lib.makeBinPath buildInputs} \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [stdenv.cc.cc.lib zlib libffi]}
    '';

    meta = with lib; {
      description = "Python environment with aider-chat";
      license = licenses.mit;
      platforms = platforms.all;
    };
  }
