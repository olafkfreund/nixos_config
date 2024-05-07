{ pkgs, ... }: {

home.packages = with pkgs; [
  python3
  python311Packages.pip
  python311Packages.pynvim
	python311Packages.pynvim-pp
  python311Packages.dbus-python
  python311Packages.ninja
  python311Packages.material-color-utilities
  python311Packages.numpy
  python311Packages.pyyaml
  calcure
  ];
}
