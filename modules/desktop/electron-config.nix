{ pkgs
, ...
}: {
  # System-wide optimization for Electron applications under Wayland
  environment = {
    # Create a global flags configuration file for all Chromium/Electron apps
    etc."electron-flags.conf".text = ''
      --enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer
      --ozone-platform=wayland
      --enable-wayland-ime
      --enable-gpu-rasterization
      --enable-zero-copy
      --ignore-gpu-blocklist
      --enable-hardware-overlays
      --disable-software-rasterizer
      --force-dark-mode
    '';

    # Create a global flags file for VS Code specifically
    etc."code-flags.conf".text = ''
      --enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer
      --ozone-platform=wayland
      --enable-wayland-ime
      --enable-gpu-rasterization
      --enable-zero-copy
      --ignore-gpu-blocklist
      --enable-hardware-overlays
    '';
  };

  # Global wrapper script for Electron apps
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "electron-wayland-launcher" ''
      #!/bin/sh
      # Usage: electron-wayland-launcher /path/to/electron/app [args...]
      export NIXOS_OZONE_WL=1
      export ELECTRON_OZONE_PLATFORM_HINT=wayland
      export ELECTRON_ENABLE_LOGGING=1
      exec "$@" --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform=wayland
    '')
  ];
}
