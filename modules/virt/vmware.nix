{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # vmware-workstation
    # ovftool
  ];
}
