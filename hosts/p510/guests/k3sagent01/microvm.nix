{ lib
, ...
}: {
  microvm.shares = [
    {
      source = "/nix/store";
      mountPoint = "/nix/.ro-store";
      tag = "ro-store";
      proto = "virtiofs";
    }
  ];

  microvm.volumes = [
    {
      autoCreate = true;
      mountPoint = "/var";
      image = "/mnt/img_pool/k3sagent01_var.img";
      size = 100 * 1024;
    }
  ];
  fileSystems."/var".neededForBoot = lib.mkForce true;

  microvm.mem = 4096;
  microvm.balloonMem = 512;

  microvm.vcpu = 2;
  microvm.interfaces = [
    {
      type = "tap";
      id = "vm-20-k3sserver";
      mac = "5E:6D:F8:D1:E8:1A";
    }
  ];
}
