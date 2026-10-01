{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    aspellDicts.uk
    aspellDicts.pl
    aspellDicts.en
    aspell
    ispell
  ];
}
