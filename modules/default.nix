{ ... }: {
  imports = [
    ./nix/nix.nix
    ./fonts/fonts.nix
    ./programs/default.nix
    ./services/default.nix
    ./security/default.nix
    ./virt/default.nix
    ./virt/spice.nix
    ./virt/incus.nix
    ./pkgs/default.nix
    ./overlays/default.nix
    ./system-scripts/default.nix
    ./nix-index/default.nix
    ./containers/default.nix
    ./cloud/default.nix
    ./ssh/ssh.nix
    ./system-utils/utils.nix
    ./system-utils/unpack.nix
    ./system-utils/system_util.nix
    ./ai/chatgpt.nix
    ./funny/funny.nix
    ./spell/spell.nix
    ./helpers/helpers.nix
    ./webcam/default.nix
    ./desktop/wlr/default.nix
    ./desktop/remote/default.nix
    ./desktop/wldash/default.nix
    ./desktop/cloud-sync/default.nix
    ./desktop/vnc/default.nix

  ];


}
