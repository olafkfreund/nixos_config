{ pkgs, ... }: {

  services.ollama = {
    enable = false;
    package = pkgs.ollama;
    acceleration = "cuda";
  };
  users.users.ollama = {
    name = "ollama";
    description = "Ollama User";
    isSystemUser = true;
    group = "ollama";
  };

  users.groups.ollama = { };

  systemd.services.ollama = {
    description = "Ollama Service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    environment = {
      OLLAMA_HOST = "0.0.0.0:11434";
      OLLAMA_ORIGINS = "http://localhost:8080";
      HOME = "/var/lib/ollama";
    };

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.ollama}/bin/ollama serve";
      User = "ollama";
      Group = "ollama";
      Restart = "always";
      KillMode = "process";
    };
  };
}
