{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # celeste # DISABLED: Build failure in nixpkgs unstable
    rclone
  ];
}
