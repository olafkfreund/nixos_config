{ pkgs, lib, ... }:

let
  version = "25.08.10.111";
  mainTarballName = "linuxx64-${version}.tar.gz";
  usbTarballName = "linuxx64-usb-${version}.tar.gz";

  localMainTarball = ./. + "/${mainTarballName}";
  localUsbTarball = ./. + "/${usbTarballName}";

  # Check if local tarballs exist
  mainExists = builtins.pathExists localMainTarball;
  usbExists = builtins.pathExists localUsbTarball;

  # Base Citrix Workspace package
  citrixBase =
    if mainExists then
      pkgs.citrix_workspace.overrideAttrs
        (_oldAttrs: {
          inherit version;
          src = pkgs.requireFile {
            name = mainTarballName;
            path = toString localMainTarball;
            sha256 = "sha256-bd3ClxBRJgvjJW+waKBE31k9ePam+n2pHeSjlkvkDRo="; # Will be updated after first download
            message = ''
              Citrix Workspace main package found at: ${toString localMainTarball}

              If you need to update the hash, run:
                ./pkgs/citrix-workspace/fetch-citrix.sh
            '';
          };
        })
    else
      throw ''
        ❌ Citrix Workspace main package not found!

        📥 To install Citrix Workspace:

        1. Run the download helper:
           ./pkgs/citrix-workspace/fetch-citrix.sh

        2. Follow the instructions to download:
           - ${mainTarballName}
           - ${usbTarballName} (recommended for USB support)

        3. Place the tarballs in: pkgs/citrix-workspace/

        4. Rebuild your system

        See docs/CITRIX-WORKSPACE-SETUP.md for detailed instructions.
      '';

  # USB Support package (optional but recommended)
  citrixUsb =
    if usbExists then
      pkgs.stdenv.mkDerivation
        {
          pname = "citrix-workspace-usb";
          inherit version;

          src = pkgs.requireFile {
            name = usbTarballName;
            path = toString localUsbTarball;
            sha256 = "sha256-bd3ClxBRJgvjJW+waKBE31k9ePam+n2pHeSjlkvkDRo="; # Will be updated after first download
            message = ''
              Citrix Workspace USB support package found at: ${toString localUsbTarball}

              If you need to update the hash, run:
                ./pkgs/citrix-workspace/fetch-citrix.sh
            '';
          };

          installPhase = ''
            mkdir -p $out
            cp -r * $out/
          '';

          meta = with lib; {
            description = "Citrix Workspace USB support package for device redirection";
            homepage = "https://www.citrix.com/";
            license = licenses.unfree;
            platforms = platforms.linux;
          };
        }
    else
      null;

in
# Return base package with USB support added if available
if citrixUsb != null then
  pkgs.symlinkJoin
  {
    name = "citrix-workspace-full-${version}";
    paths = [ citrixBase citrixUsb ];
    meta = citrixBase.meta // {
      description = "Citrix Workspace with USB support";
    };
  }
else
  citrixBase
