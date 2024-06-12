{
  services.postgres = {
    service.image = "postgres:10";
    service.volumes = [ "${toString ./.}/postgres-data:/var/lib/postgresql/data" ];
    service.environment.POSTGRES_PASSWORD = "mydefaultpass";
  };
}
