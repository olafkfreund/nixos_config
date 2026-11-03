{ pkgs, ... }: {
  home.packages = [
    (pkgs.writeShellApplication {
      name = "agent-run";
      runtimeInputs = with pkgs; [ git jq coreutils gnugrep ];
      text = builtins.readFile ./agent-run.sh;
    })
  ];
}
