_final: prev:
let
  version = "2508.10";
  mainTarballName = "linuxx64-${version}.tar.gz";
  usbTarballName = "linuxx64-usb-${version}.tar.gz";
  configDir = builtins.getEnv "PWD";
  localMainTarball = "${configDir}/pkgs/citrix-workspace/${mainTarballName}";
  localUsbTarball = "${configDir}/pkgs/citrix-workspace/${usbTarballName}";

  mainExists = builtins.pathExists localMainTarball;
  usbExists = builtins.pathExists localUsbTarball;

  # Base Citrix Workspace package
  citrixBase =
    if mainExists then
      prev.citrix_workspace.overrideAttrs
        (_oldAttrs: {
          inherit version;
          src = prev.requireFile {
            name = mainTarballName;
            path = localMainTarball;
            sha256 = "0000000000000000000000000000000000000000000000000000"; # Placeholder - will be updated after download
            message = ''
              Citrix Workspace main package found at: ${localMainTarball}

              If hash verification fails, run:
                ./pkgs/citrix-workspace/fetch-citrix.sh
            '';
          };
        })
    else
      throw ''
        ❌ Citrix Workspace main package not found!

        📥 To install Citrix Workspace version ${version}:

        1. Run the download helper:
           cd /home/olafkfreund/.config/nixos
           ./pkgs/citrix-workspace/fetch-citrix.sh

        2. Follow the instructions to download:
           - ${mainTarballName} (main package)
           - ${usbTarballName} (USB support - recommended)

        3. Place the tarballs in: pkgs/citrix-workspace/

        4. Rebuild your system

        See docs/CITRIX-WORKSPACE-SETUP.md for detailed instructions.

        Expected files:
          - ${localMainTarball}
          - ${localUsbTarball} (optional)
      '';

  # USB Support package
  citrixUsb =
    if usbExists then
      prev.stdenv.mkDerivation
        {
          pname = "citrix-workspace-usb";
          inherit version;

          src = prev.requireFile {
            name = usbTarballName;
            path = localUsbTarball;
            sha256 = "0000000000000000000000000000000000000000000000000000"; # Placeholder - will be updated after download
            message = ''
              Citrix Workspace USB support package found at: ${localUsbTarball}

              If hash verification fails, run:
                ./pkgs/citrix-workspace/fetch-citrix.sh
            '';
          };

          installPhase = ''
            mkdir -p $out
            cp -r * $out/
          '';

          meta = with prev.lib; {
            description = "Citrix Workspace USB support package for device redirection";
            homepage = "https://www.citrix.com/";
            license = licenses.unfree;
            platforms = platforms.linux;
          };
        }
    else
      null;
in
{
  # Override citrix_workspace with full package including USB support
  citrix_workspace =
    if citrixUsb != null then
      prev.symlinkJoin
        {
          name = "citrix-workspace-full-${version}";
          paths = [ citrixBase citrixUsb ];
          meta = citrixBase.meta // {
            description = "Citrix Workspace with USB support";
          };
        }
    else
      citrixBase;
}
