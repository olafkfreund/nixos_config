{pkgs, ...}: {
  # Define your custom packages here
  # msty = pkgs.callPackage ./msty {};
  # aider-chat-env = pkgs.callPackage ./aider-chat-env {};
  rofi-blocks = pkgs.callPackage ./rofi-blocks {};
  chrome-gruvbox-theme = pkgs.callPackage ./chrome-gruvbox-theme {};
  linux-command-mcp = pkgs.callPackage ./linux-command-mcp {};
  mpris-album-art = pkgs.callPackage ./mpris-album-art {};
  weather-popup = pkgs.callPackage ./weather-popup {};
  gemini-cli = pkgs.callPackage ./gemini-cli {};
  # amd-smi-exporter = pkgs.callPackage ./amd-smi-exporter.nix {};  # Commented out until build issues resolved
}
