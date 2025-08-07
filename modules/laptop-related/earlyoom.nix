{ ... }: {
  services = {
    earlyoom = {
      enable = false;          # Enable the early OOM (Out Of Memory) killer service.
      freeMemThreshold = 5;
    };
  };
}
