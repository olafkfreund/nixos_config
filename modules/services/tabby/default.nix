{pkgs-unstable, ...}: {
  services.tabby = {
    enable = true;
    package = pkgs-unstable.tabby;
    model = "TabbyML/DeepSeek-Coder-V2-Lite";
    acceleration = "rocm";
  };
}
