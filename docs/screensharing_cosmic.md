# Enabling Full Screen Sharing in Teams PWA on Chrome with NixOS and Cosmic DE

**Microsoft Teams PWA screen sharing on NixOS with Cosmic DE requires three critical components working together: xdg-desktop-portal-cosmic (the portal backend), PipeWire (multimedia transport), and Chrome configured for native Wayland.** The issue where only tab sharing works indicates the portal/PipeWire chain is broken, while Chrome's internal tab capture still functions. Cosmic DE currently has beta-quality screensharing with known limitations for full screen capture, though window sharing generally works.

The core problem stems from how Wayland screen sharing works differently than tab sharing. Chrome's built-in tab capture operates entirely within the browser process and doesn't require external components. However, window and screen sharing require the complete chain: Browser → xdg-desktop-portal → xdg-desktop-portal-cosmic → cosmic-comp compositor → PipeWire → back to browser. When this chain has any missing or misconfigured component, only tab sharing functions.

Cosmic DE is in beta (Epoch 1 Beta released September 2025) with actively developed screensharing support. While basic functionality works for many users, there are documented issues with full screen sharing (Issue #75 reports screen sharing dialog appears but sharing fails with buffer constraint errors) while individual window sharing typically succeeds. This guide provides the complete configuration to maximize compatibility given Cosmic's current maturity.

## Required Wayland screensharing components

The Wayland screensharing architecture uses a frontend/backend separation pattern where **xdg-desktop-portal** acts as the desktop-agnostic D-Bus service that applications communicate with, while **desktop-specific backends** handle the actual compositor integration and UI. PipeWire serves as the multimedia transport layer that streams video frames from the compositor to applications.

For Cosmic DE specifically, you need **xdg-desktop-portal-cosmic** (available at github.com/pop-os/xdg-desktop-portal-cosmic), which is the Rust-based portal backend implementing the ScreenCast interface. This backend communicates with **cosmic-comp** (the Smithay-based Wayland compositor) using a custom zcosmic-screencopy-manager protocol, though the team is transitioning to standard ext-image-copy-capture-v1 protocol. PipeWire version 0.3.33 or newer is required for compatibility, along with **WirePlumber** as the session manager (the older pipewire-media-session is deprecated).

The complete component list: xdg-desktop-portal (frontend service), xdg-desktop-portal-cosmic (Cosmic-specific backend), xdg-desktop-portal-gtk (fallback for file choosers), pipewire and pipewire-pulse, wireplumber, and rtkit for realtime scheduling. All these components communicate via D-Bus and require proper environment variables (WAYLAND_DISPLAY, XDG_CURRENT_DESKTOP) to be imported into the systemd user session.

## NixOS configuration.nix settings

Configure your NixOS system with this complete configuration that enables all necessary screensharing components. The configuration enables PipeWire as the primary multimedia service, sets up xdg-desktop-portal with the Cosmic backend, and ensures proper environment variable handling.

```nix
{ config, pkgs, lib, ... }:

{
  # Enable PipeWire for multimedia transport
  security.rtkit.enable = true;  # Realtime scheduling for low latency
  services.pipewire = {
    enable = true;
    alsa.enable = true;           # ALSA support
    alsa.support32Bit = true;     # 32-bit app compatibility
    pulse.enable = true;          # PulseAudio compatibility layer
  };

  # Configure XDG Desktop Portal for screensharing
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-cosmic  # Cosmic DE portal backend
      xdg-desktop-portal-gtk     # Fallback for file picker dialogs
    ];

    # Explicit portal configuration (NixOS 23.05+)
    config = {
      cosmic = {
        default = ["cosmic" "gtk"];
        "org.freedesktop.impl.portal.FileChooser" = ["gtk"];
      };
    };
  };

  # Enable polkit for authentication dialogs
  security.polkit.enable = true;

  # Enable dconf (required for GTK applications)
  programs.dconf.enable = true;

  # Ensure Chrome/Chromium packages are available
  environment.systemPackages = with pkgs; [
    google-chrome  # or chromium
    pipewire       # PipeWire command-line tools
  ];
}
```

After modifying configuration.nix, apply changes with `sudo nixos-rebuild switch`. The portal services use socket activation and start automatically when applications request screensharing, so you don't need to manually start them. However, environment variables must be properly imported into your systemd user session for the portals to detect your Wayland session.

For users coming from other desktop environments, note that the `extraPortals` order matters when multiple backends are installed - the first matching portal is used. Using `xdg.portal.config` provides explicit control over which backend handles each portal interface, preventing conflicts if you have multiple desktop environments installed.

If you're using Cosmic from a flake or unstable channel, ensure you're pulling from nixpkgs-unstable or the cosmic-specific overlay, as stable channels may have outdated versions. The xdg-desktop-portal-cosmic package should be version 1.0.0-alpha.7 or newer for best compatibility.

## Chrome/Chromium flags and Wayland settings

Chrome requires specific configuration to enable native Wayland support and PipeWire-based screensharing. The most reliable configuration method is creating a persistent flags file that applies every time Chrome launches, rather than manually typing flags each time.

Create `~/.config/chrome-flags.conf` (for Google Chrome) or `~/.config/chromium-flags.conf` (for Chromium) with these flags:

```
--ozone-platform-hint=auto
--enable-features=WebRTCPipeWireCapturer
--enable-wayland-ime
```

**What each flag does:** The `--ozone-platform-hint=auto` flag enables Chrome's Ozone platform abstraction to automatically detect and use Wayland when available (Chrome 98+). For older Chrome versions or certain compositors, you may need the explicit `--ozone-platform=wayland` instead. The `--enable-features=WebRTCPipeWireCapturer` flag enables PipeWire backend for WebRTC screen capture (note: Chrome 110+ has this enabled by default, but explicitly setting it ensures compatibility). The `--enable-wayland-ime` flag enables proper input method support on Wayland.

Alternatively, configure via chrome://flags by navigating to the browser UI and searching for "Preferred Ozone platform" (set to Auto or Wayland) and "WebRTC PipeWire support" (set to Enabled). This method works but is less persistent across Chrome updates.

For Microsoft Teams PWA specifically, the PWA inherits all flags from the parent Chrome/Chromium browser, so no additional configuration is needed beyond the main browser setup. The old Teams desktop app (Electron-based) was deprecated in December 2023, and Microsoft now recommends the PWA version which has better Wayland support. Install the Teams PWA by visiting teams.microsoft.com in Chrome and clicking the install icon in the address bar.

**Verification that Chrome is using Wayland:** Navigate to `chrome://gpu` and search for "ozone-platform" - it should show "wayland". Also check `chrome://version` and look for `--ozone-platform=wayland` or `--ozone-platform-hint=auto` in the Command Line section. If you see "XDG_SESSION_TYPE: wayland" in chrome://gpu, Chrome has correctly detected your Wayland session.

## Cosmic DE specific configurations

Cosmic DE requires minimal additional configuration beyond the standard portal setup, as the desktop environment automatically sets appropriate environment variables and the portal backend integrates directly with cosmic-comp. However, there are several Cosmic-specific considerations due to its beta status.

**Environment variable handling:** Cosmic should automatically set `XDG_CURRENT_DESKTOP=COSMIC` when you log in. Verify this with `echo $XDG_CURRENT_DESKTOP`. The portal system uses this variable to determine which backend to use. If for any reason this variable isn't set, add it to your session startup.

**Current protocol implementation:** Cosmic currently uses a custom **zcosmic-screencopy-manager** protocol for screen capture rather than the standard wlr-screencopy protocol used by wlroots-based compositors. The development team is actively working on implementing the standard ext-image-copy-capture-v1 protocol (PR #365 in cosmic-comp), which will improve compatibility with various screen capture tools. This means some applications that expect wlr-screencopy won't work with Cosmic.

**Known limitations in Cosmic Beta:** The most significant known issue (GitHub Issue #75) is that full screen sharing can fail with "screencopy failed: Value(BufferConstraints)" and GL_INVALID_VALUE errors, even though the selection dialog appears. Individual window sharing typically works more reliably than full screen sharing. Testing with Slack and Chrome has reproduced this issue consistently for some users. Another limitation is that Discord screen sharing may show a spinning wheel indefinitely on some hardware configurations, particularly with NVIDIA GPUs.

**OBS Studio and screen recording:** For general screen recording tools like OBS Studio, use the PipeWire source rather than attempting direct compositor access. Cosmic-comp supports DMA-BUF capture which provides better performance for recording tools that support it.

No additional configuration files in ~/.config/cosmic/ are needed for basic screensharing functionality. The portal backend handles all compositor communication automatically. However, if you're debugging issues, you may want to enable verbose logging for the portal service.

## Verification that setup is working correctly

Systematic verification ensures each component in the screensharing chain functions properly. Start with the foundation and work up to browser testing.

**Step 1: Verify PipeWire is running**

```bash
systemctl --user status pipewire wireplumber
```

Both services should show "active (running)". If not running, start them with `systemctl --user start pipewire wireplumber`. You can also check PipeWire's status with `wpctl status`, which should list audio and video devices.

**Step 2: Check portal services**

```bash
systemctl --user status xdg-desktop-portal xdg-desktop-portal-cosmic
```

These services typically start on-demand via socket activation, so they may show as "inactive (dead)" until you attempt screensharing. This is normal. After attempting to screenshare once, they should be active.

**Step 3: Verify environment variables**

```bash
systemctl --user show-environment | grep -E 'WAYLAND_DISPLAY|XDG_CURRENT_DESKTOP'
```

Should output something like:

```
WAYLAND_DISPLAY=wayland-0
XDG_CURRENT_DESKTOP=COSMIC
```

If these are missing, the portal services cannot detect your session. Fix by running:

```bash
systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
```

**Step 4: Check installed portal backends**

```bash
ls /usr/share/xdg-desktop-portal/portals/
```

Should list `cosmic.portal` and `gtk.portal` files. These files declare which portal interfaces each backend implements.

**Step 5: Test Chrome Wayland detection**
Open Chrome and navigate to `chrome://gpu`. Press Ctrl+F and search for "wayland". You should see "ozone-platform=wayland" or similar indicating native Wayland mode. Also verify "XDG_SESSION_TYPE: wayland" appears in the output. If Chrome is running in XWayland mode instead, screensharing won't access native Wayland windows.

**Step 6: Functional screensharing test**
Visit the WebRTC test page at `https://mozilla.github.io/webrtc-landing/gum_test.html`. Click "getDisplayMedia" button. You should see the Cosmic portal selection dialog appear, allowing you to choose between windows and outputs (monitors). Select a window or screen and click "Share". The video preview should show your selected content. Test both window selection and full screen selection to identify which works.

**Step 7: Test in Teams PWA**
Open Microsoft Teams PWA, join a meeting, and click the share screen button. The same Cosmic portal dialog should appear. Try sharing a specific application window first (more reliable), then test full screen sharing.

## Troubleshooting steps if screen sharing still doesn't work

When screensharing fails despite correct configuration, systematic diagnosis identifies which component in the chain is broken. The most common failure modes have specific symptoms and solutions.

**Symptom: Only tab sharing works, no window/screen sharing option appears**
This indicates Chrome cannot communicate with xdg-desktop-portal. Check that PipeWire flag is enabled in chrome://flags. Verify portal services are installed with `ls /usr/share/xdg-desktop-portal/portals/`. Ensure environment variables are set in systemd user session (see verification section). Restart Chrome completely (including background processes) after changing flags.

**Symptom: Selection dialog appears but sharing produces black screen**
This specific issue is **very common in Cosmic Beta** and indicates the portal/compositor communication is failing. Check portal logs with `journalctl --user -u xdg-desktop-portal-cosmic -f` while attempting to share. Look for "screencopy failed" or "BufferConstraints" errors. Workaround: Try sharing individual windows instead of full screen, as window sharing has better success rates. Also verify your GPU drivers are up-to-date, as GL texture errors often indicate driver issues.

**Symptom: Discord/Slack shows spinning wheel or immediate failure**
This application-specific issue often relates to how Electron apps detect the portal. Ensure Discord/Slack are launched with Wayland flags enabled. For Electron apps, you may need to create custom desktop files or wrappers that add `--enable-features=WebRTCPipeWireCapturer --ozone-platform=wayland` flags. Some users have reported Discord specifically has issues with Cosmic (GitHub Issue #913).

**Symptom: Permission denied or "Request not allowed" errors**
The portal dialog may have been dismissed or permissions denied previously. Clear permissions with:

```bash
# Check current permissions
flatpak permissions devices camera
# Remove if needed
flatpak permission-remove devices camera org.google.Chrome
```

**Symptom: Zoom native app doesn't show screen picker**
This is a known issue (GitHub Issue #77) with Zoom's native application. Workaround: Use Zoom PWA instead by visiting zoom.us in Chrome and installing as PWA. The PWA uses Chrome's screensharing implementation which works properly.

**Debug logging for detailed diagnosis:**
Enable verbose logging for portal components:

```bash
# Stop existing portal services
systemctl --user stop xdg-desktop-portal xdg-desktop-portal-cosmic

# Start with debug logging
/usr/lib/xdg-desktop-portal -r -v &
journalctl --user -u xdg-desktop-portal-cosmic -f
```

Then attempt screensharing and watch the log output for errors. Common errors include "No such interface org.freedesktop.impl.portal.ScreenCast" (backend missing), "Failed to create PipeWire stream" (PipeWire not running), or compositor-specific errors.

**NVIDIA GPU specific issues:**
If you're using NVIDIA proprietary drivers, several users have reported issues with Cosmic screensharing (particularly on RTX 2060 with driver 560.28.03). The GL texture errors in Issue #75 may indicate driver compatibility problems. Ensure you're using the latest NVIDIA driver available for your NixOS version. Consider testing with `nouveau` open-source drivers to determine if it's driver-related.

**Hardware acceleration conflicts:**
Sometimes hardware acceleration causes issues with screensharing. Test by disabling it: Visit chrome://flags and disable "Hardware-accelerated video decode" and "GPU rasterization". If this fixes screensharing, you have a driver/acceleration issue. The proper fix is updating GPU drivers rather than permanently disabling acceleration.

**Restart compositor as last resort:**
If all else fails, log out and back into Cosmic. This reinitializes cosmic-comp and all related services. The portal services are socket-activated and sometimes get into inconsistent states that require a full session restart to resolve.

**Alternative testing approach:**
If Teams continues to fail, test with a simpler application first. Firefox with `MOZ_ENABLE_WAYLAND=1` has excellent Wayland support. Test screensharing in Firefox at the WebRTC test page to determine if the issue is Cosmic/PipeWire (affects all apps) or Chrome-specific (Firefox works but Chrome doesn't).

## Important notes about Cosmic DE maturity

Cosmic DE is currently in **Epoch 1 Beta** (released September 2025) with active development toward a stable release. While System76's official statement claims "screen-sharing in video conferencing apps is now functional," GitHub issues reveal this isn't universally true across all applications and hardware configurations.

The screensharing implementation is **partially mature** with working window selection but known issues with full screen capture. Individual window sharing generally succeeds, but attempting to share entire screens can trigger buffer constraint errors that cause sharing to fail silently (the dialog completes successfully but no video is transmitted). This limitation affects production use cases where full screen sharing is required.

Cosmic is using a **custom screencopy protocol** (zcosmic-screencopy-manager) rather than standard Wayland protocols while the team works on implementing ext-image-copy-capture-v1. This means applications that expect wlr-screencopy (used by Sway, Hyprland, etc.) won't work with Cosmic. The transition to standard protocols is tracked in cosmic-comp PR #365.

For production environments requiring reliable screensharing, consider that Cosmic is best suited for testing and development use cases at this stage. The development team is actively fixing issues as they move toward stable release, but if screensharing is business-critical, you may want to wait for the stable release or maintain a fallback to a mature desktop environment like GNOME or KDE Plasma for important meetings.

## Summary

Enabling full screen sharing in Microsoft Teams PWA on Chrome with NixOS and Cosmic DE requires configuring three layers: system services (PipeWire and portals via configuration.nix), browser flags (Chrome Wayland and PipeWire flags), and understanding Cosmic's current beta limitations. The complete configuration involves enabling pipewire with wireplumber, adding xdg-desktop-portal-cosmic to xdg.portal.extraPortals, and creating ~/.config/chrome-flags.conf with Wayland flags.

The key insight is that tab sharing works independently of this infrastructure because it's built into Chrome, while window/screen sharing requires the complete portal chain. Given Cosmic's beta status with documented screensharing issues, expect individual window sharing to be more reliable than full screen sharing currently. If you encounter the buffer constraints error, this is a known Cosmic limitation rather than a configuration problem on your end.

Verify your setup systematically: check PipeWire and portal services are running, confirm environment variables are set in systemd user session, verify Chrome detects Wayland in chrome://gpu, and test with the WebRTC test page before attempting Teams meetings. When issues persist, focus troubleshooting on portal logs with journalctl and consider testing window sharing as a workaround for full screen sharing failures.
