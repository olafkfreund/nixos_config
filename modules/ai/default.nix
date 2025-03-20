{pkgs, ...}: {
  # Define your custom packages here
  msty = pkgs.callPackage ./msty {};
  aider-chat-env = pkgs.callPackage ./aider-chat-env {};
}
