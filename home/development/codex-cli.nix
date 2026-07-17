{ pkgs, ... }:

{
  imports = [ ./codex-cli/module.nix ];

  programs.codex-cli = {
    enable = true;

    # API key for the headless path. codex (Rust) reads OPENAI_API_KEY, or use
    # `codex login` for ChatGPT auth. Sourced from the agenix secret.
    apiKeyFile = "/run/agenix/api-openai";

    # `codex` is the real binary name from nixpkgs#codex. The rest are
    # convenience aliases so existing muscle memory keeps working.
    shellAliases = {
      ai-code = "codex";
      openai-codex = "codex";
      cx = "codex";
      code-ai = "codex";
      codex-project = "codex-project";
      cx-project = "codex-project";
      cx-analyze = "codex-project analyze";
      cx-ask = "codex-project ask";
    };
  };

  # Complementary dev tooling that pairs well with AI-assisted coding.
  # codex itself configures via ~/.codex/config.toml, which it self-manages —
  # nothing declarative is written there from Nix.
  home.packages = with pkgs; [
    prettier
    eslint
    python313Packages.black # Python formatter (pin py3.13 to match languages.nix/nvim.nix; bare `black` is py3.14 now and collides in home-manager-path)
    rustfmt # Rust formatter
    nixpkgs-fmt # Nix formatter
    jq # JSON processing for API responses
    curl # API testing
    httpie # User-friendly HTTP client
  ];
}
