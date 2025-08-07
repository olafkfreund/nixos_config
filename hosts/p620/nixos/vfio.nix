let
  # RTX 3070 Ti
  gpuIDs = [
    "10de:2504" # Graphics
    "10de:228e" # Audio
  ];
in
  {
    lib,
    config,
    ...
  }: {
    options.vfio.enable = with lib;
      mkEnableOption "Configure the machine for VFIO";

    config = let
      cfg = config.vfio;
    in {
      boot = {
        initrd.kernelModules = [
          "vfio_pci"
          "vfio"
          "vfio_iommu_type1"
          "vfio_virqfd"
        ];

        kernelParams =
          [
            # enable IOMMU
            "amd_iommu=on"
          ]
          ++ lib.optional cfg.enable
          # isolate the GPU
          ("vfio-pci.ids=" + lib.concatStringsSep "," gpuIDs);
      };

      virtualisation.spiceUSBRedirection.enable = true;
    };
  }
