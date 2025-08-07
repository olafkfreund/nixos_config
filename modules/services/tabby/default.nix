{ pkgs-unstable, ... }: {
  services.tabby = {
    enable = true;
    package = pkgs-unstable.tabby;
    model = "TabbyML/DeepseekCoder-6.7B";
    acceleration = "rocm";
    indexInterval = "5hours";
  };
  environment.systemPackages = with pkgs-unstable; [
    tabby-agent
  ];
}
