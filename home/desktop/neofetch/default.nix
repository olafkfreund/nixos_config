{
  pkgs,
  config,
  ...
}: {
  home.file.".config/neofetch/config.conf".text = ''
    print_info() {
        prin "$(color 6)  NIXOS "
        info underline
        info "$(color 7)  VER" kernel
        info "$(color 2)  UP " uptime
        info "$(color 4)  PKG" packages
        info "$(color 6)  DE " de
        info "$(color 5)  TER" term
        info "$(color 3)  CPU" cpu
        info "$(color 7)  GPU" gpu
        info "$(color 5)  MEM" memory
        prin " "
        prin "$(color 1) $(color 2) $(color 3) $(color 4) $(color 5) $(color 6) $(color 7) $(color 8)"
    }
    distro_shorthand="on"
    memory_unit="gib"
    cpu_temp="C"
    separator=" $(color 4)>"
    stdout="off"
    image_backend="kitty"
    image_source=$HOME/Pictures/wallpapers/gruvbox/finalizer.png
    image_size="100px"
    crop_mode="normal"
    crop_offset="west"
  '';
}
