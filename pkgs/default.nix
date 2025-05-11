{pkgs, ...}: {
  # Define your custom packages here
  # msty = pkgs.callPackage ./msty {};
  # aider-chat-env = pkgs.callPackage ./aider-chat-env {};
  rofi-blocks = pkgs.callPackage ./rofi-blocks {};
  chrome-gruvbox-theme = pkgs.callPackage ./chrome-gruvbox-theme {};
}
