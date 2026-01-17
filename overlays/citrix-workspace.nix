_final: prev:
let
  version = "25.08.10.111";
  tarballName = "linuxx64-${version}.tar.gz";
in
{
  # Override citrix_workspace with local tarball
  citrix_workspace = prev.citrix_workspace.overrideAttrs (oldAttrs: {
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

    # Add runtime dependencies for bundled webkit2gtk
    buildInputs = (oldAttrs.buildInputs or [ ]) ++ (with prev; [
      libnotify
      libxslt
      lcms2
      woff2
      harfbuzzFull # Provides libharfbuzz-icu.so.0 needed by bundled webkit
      libjpeg8 # Provides libjpeg.so.8 needed by bundled webkit (not libjpeg which is v62)
      enchant_2
      hyphen
      libseccomp
      libmanette # Provides libmanette-0.2.so.0 needed by bundled webkit
    ]);

    # Extract bundled webkit2gtk during installation
    postInstall = (oldAttrs.postInstall or "") + ''
      # Extract bundled webkit2gtk-4.0 tarball
      if [ -f "$out/opt/citrix-icaclient/Webkit2gtk4.0/webkit2gtk-4.0.tar.gz" ]; then
        echo "Extracting bundled webkit2gtk-4.0..."
        mkdir -p "$out/opt/citrix-icaclient/Webkit2gtk4.0/extracted"
        tar -xzf "$out/opt/citrix-icaclient/Webkit2gtk4.0/webkit2gtk-4.0.tar.gz" \
          -C "$out/opt/citrix-icaclient/Webkit2gtk4.0/extracted"

        # Add webkit2gtk libraries to library path
        WEBKIT_LIB_PATH="$out/opt/citrix-icaclient/Webkit2gtk4.0/extracted/webkit2gtk-4.0-package/usr/lib/x86_64-linux-gnu"
        if [ -d "$WEBKIT_LIB_PATH" ]; then
          echo "Copying webkit2gtk libraries..."
          cp -r "$WEBKIT_LIB_PATH"/* "$out/opt/citrix-icaclient/lib/" || true
        fi
      fi
    '';

    # Only ignore fuse3 (optional feature) and version-specific libs
    # fuse3 is for filesystem redirection (optional feature)
    # version-specific libraries that differ from nixpkgs versions
    autoPatchelfIgnoreMissingDeps = [
      "libfuse3.so.3"
      "libwoff2dec.so.1.0.2" # woff2 package provides different version
    ];
  });
}
