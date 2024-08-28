{ pkgs, ... }:
 {
    home.packages = with pkgs; [
      obsidian
      obsidian-export
      ];
}
