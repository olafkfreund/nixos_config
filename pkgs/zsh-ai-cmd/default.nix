{ lib
, stdenv
, fetchFromGitHub
, curl
, jq
}:

stdenv.mkDerivation rec {
  pname = "zsh-ai-cmd";
  version = "unstable-2025-01-29";

  src = fetchFromGitHub {
    owner = "kylesnowschwartz";
    repo = "zsh-ai-cmd";
    rev = "101219afe7345a44753fe3d2b8c3736884da0e40";
    hash = "sha256-WCYQfpZCkrKxRcH8ZtmsdwehNxz8QyErGTvxrgYH9s8=";
  };

  strictDeps = true;

  # Runtime dependencies that need to be in PATH (provided by module)
  propagatedBuildInputs = [ curl jq ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Create plugin directory
    plugindir="$out/share/zsh/plugins/zsh-ai-cmd"
    mkdir -p "$plugindir"

    # Install plugin files
    install -Dm644 zsh-ai-cmd.plugin.zsh "$plugindir/zsh-ai-cmd.plugin.zsh"
    install -Dm644 prompt.zsh "$plugindir/prompt.zsh"

    runHook postInstall
  '';

  # Dependencies will be provided by the NixOS module
  passthru = {
    runtimeDeps = [ curl jq ];
  };

  meta = with lib; {
    description = "AI-powered shell command suggestions using Anthropic Claude";
    longDescription = ''
      zsh-ai-cmd provides intelligent command suggestions powered by Claude AI,
      displaying suggestions as non-intrusive ghost text triggered by a keybinding
      (default: Ctrl+Z). Suggestions appear in dim grey text and can be accepted
      with Tab or dismissed by continuing to type.

      Features:
      - Ghost text display using ZLE's POSTDISPLAY variable
      - Non-blocking API calls with animated spinner feedback
      - Context-aware suggestions (includes OS, shell, current directory)
      - Configurable Claude model selection
      - Debug logging support

      Requirements:
      - Anthropic API key (configured via environment or secret management)
      - Modern zsh with ZLE widget support
      - curl and jq for API communication
    '';
    homepage = "https://github.com/kylesnowschwartz/zsh-ai-cmd";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    platforms = platforms.unix;
    mainProgram = "zsh-ai-cmd.plugin.zsh";
  };
}
