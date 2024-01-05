{ pkgs, ... }: {

home.packages = with pkgs; [
  python3
  python311Packages.pip
  python311Packages.pynvim
	python311Packages.pynvim-pp
  ];
}
