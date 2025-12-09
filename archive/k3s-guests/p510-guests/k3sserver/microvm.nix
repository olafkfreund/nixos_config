{ lib, ... }: {
  microvm = {
    shares = [
      {
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
        tag = "ro-store";
        proto = "virtiofs";
      }
    ];

    volumes = [
      {
        autoCreate = true;
        mountPoint = "/var";
        image = "/mnt/img_pool/k3sserver_var.img";
        size = 100 * 1024;
      }
    ];

    mem = 4096;
    balloonMem = 512;

    vcpu = 2;
    interfaces = [
      {
        type = "tap";
        id = "vm-20-k3sserver";
        mac = "5E:6D:F8:D1:E8:AA";
      }
    ];
  };

  fileSystems."/var".neededForBoot = lib.mkForce true;
}
