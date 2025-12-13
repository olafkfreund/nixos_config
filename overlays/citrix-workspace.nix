_final: prev:
let
  version = "25.08.10.111";
  tarballName = "linuxx64-${version}.tar.gz";
  configDir = builtins.getEnv "PWD";
  localTarball = "${configDir}/pkgs/citrix-workspace/${tarballName}";
  tarballExists = builtins.pathExists localTarball;
in
{
  citrix_workspace =
    if tarballExists then
    # Use local tarball if it exists
      prev.citrix_workspace.overrideAttrs
        (_oldAttrs: {
          inherit version;
          src = prev.requireFile {
            name = tarballName;
            path = localTarball;
            sha256 = "sha256-bd3ClxBRJgvjJW+waKBE31k9ePam+n2pHeSjlkvkDRo="; # Placeholder - will be updated after download
            message = ''
              Citrix Workspace package found at: ${localTarball}

              If hash verification fails, run:
                ./pkgs/citrix-workspace/fetch-citrix.sh
            '';
          };
        })
    else
    # Provide helpful error message if tarball not found
      throw ''
        ❌ Citrix Workspace package not found!

        📥 To install Citrix Workspace version ${version}:

        1. Run the download helper:
           cd /home/olafkfreund/.config/nixos
           ./pkgs/citrix-workspace/fetch-citrix.sh

        2. Follow the instructions to download ${tarballName}
           (USB support is included in the main package)

        3. Place the tarball in: pkgs/citrix-workspace/

        4. Rebuild your system

        See docs/CITRIX-WORKSPACE-SETUP.md for detailed instructions.

        Expected file: ${localTarball}
      '';
}
