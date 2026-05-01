final: _prev: {
  glim = final.callPackage ./glim { };
  intune-portal = final.callPackage ../pkgs/intune-portal { };
  zsh-ai-cmd = final.callPackage ../pkgs/zsh-ai-cmd { };
  claude-code-native = final.callPackage ../pkgs/claude-code-native { };
  warp-terminal = final.callPackage ../pkgs/warp-terminal { };
  gemini-cli = final.callPackage ../home/development/gemini-cli { };
}
