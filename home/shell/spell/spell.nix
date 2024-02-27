{ pkgs, config, lib, ... }: {

home.packages = with pkgs; [
  aspellDicts.uk
  aspellDicts.pl
  aspellDicts.en
  aspellDicts.en-computers
  aspellDicts.en-science
  aspell
  ispell
  ];
}
