_final: prev:
let
  version = "25.08.10.111";
  tarballName = "linuxx64-${version}.tar.gz";
in
{
  # Override citrix_workspace with local tarball
  citrix_workspace = prev.citrix_workspace.overrideAttrs (_oldAttrs: {
    inherit version;
    src = prev.requireFile {
      name = tarballName;
      url = "https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html";
      sha256 = "sha256-bd3ClxBRJgvjJW+waKBE31k9ePam+n2pHeSjlkvkDRo=";
      message = ''
        ❌ Citrix Workspace ${version} tarball not found in Nix store!

        📥 To install Citrix Workspace:

        1. Download manually from Citrix:
           https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html

        2. Accept the EULA and download: ${tarballName}
           (USB support is included - do NOT download separate .deb)

        3. Place the tarball in your config directory:
           /home/olafkfreund/.config/nixos/pkgs/citrix-workspace/${tarballName}

        4. Add to Nix store:
           nix-store --add-fixed sha256 /home/olafkfreund/.config/nixos/pkgs/citrix-workspace/${tarballName}

        5. Rebuild your system:
           sudo nixos-rebuild switch

        See docs/CITRIX-WORKSPACE-SETUP.md for detailed instructions.
      '';
    };

    # Ignore webkit2gtk and fuse3 dependencies
    # webkit2gtk is bundled in Citrix 25.08.10.111+
    # fuse3 is for filesystem redirection (optional feature)
    # See: https://docs.citrix.com/en-us/citrix-workspace-app-for-linux/system-requirements.html
    autoPatchelfIgnoreMissingDeps = [
      "libwebkit2gtk-4.0.so.37"
      "libjavascriptcoregtk-4.0.so.18"
      "libfuse3.so.3"
    ];
  });
}
