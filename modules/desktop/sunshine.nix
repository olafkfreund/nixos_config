{ config
, lib
, pkgs
, ...
}:
# Sunshine: stream this machine's Wayland session to a Moonlight client.
#
# This exists because p510 gained a monitor and an Omarchy session, and the
# remote path it used to have does not reach that session. gnome-remote-desktop
# serves GNOME -- it is a GNOME Shell component using GNOME's own screencast
# pipeline -- so with Hyprland as the session there is nothing on the other end
# of RDP. Sunshine captures the compositor's output directly instead, which is
# compositor-agnostic, and encodes on the GPU.
#
# Two things about this service are unusual enough to state:
#
#   It is a systemd USER service, not a system one. Upstream's module puts it in
#   the user session because it has to talk to the running compositor. So it
#   comes up when a graphical session does and not a moment sooner: on a host
#   that reboots unattended, remote access therefore depends on that session
#   existing without a human at the keyboard. That is why p510 keeps autologin
#   on while p620 and razer do not.
#
#   The hardening rules in CLAUDE.md do not apply and cannot. DynamicUser,
#   ProtectHome and ProtectSystem = "strict" all assume a service that needs
#   nothing of the user's session; this one needs the user's Wayland socket,
#   their GPU device nodes and their input devices. Sandboxing it to the point
#   the rules ask for is the same as switching it off, so the deliberate
#   exception is recorded here rather than silently taken.
let
  inherit (lib) mkIf mkEnableOption mkOption types;
  cfg = config.features.sunshine;

  # Wake the output before a stream starts.
  #
  # Sunshine captures whatever the compositor puts on the monitor, so a
  # DPMS-off output streams as solid black -- with a completely clean log:
  # CLIENT CONNECTED, capture on the right monitor, encoder running, no
  # errors, nothing to suggest the picture is missing rather than dark.
  #
  # hyprctl comes from /run/current-system/sw/bin deliberately, not from
  # pkgs.hyprland. omarchy-sole-hyprland.nix puts the Hyprland that nixarchy
  # pins into the system profile, and that is the build actually running the
  # session; nixpkgs carries a different version, and the Lua dispatcher API
  # this calls is version-sensitive.
  #
  # The signature is resolved from the runtime directory rather than trusted
  # from the environment: this runs from a systemd user service that need not
  # have inherited HYPRLAND_INSTANCE_SIGNATURE from the session.
  #
  # It always exits 0. Sunshine aborts the whole stream if a prep command
  # fails, so a host with no Hyprland running, or a renamed dispatcher after
  # an upgrade, must degrade to "no wake" and not to "no streaming".
  wakeDisplayScript = pkgs.writeShellScript "sunshine-wake-display" ''
    set -u
    runtime="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    sig="''${HYPRLAND_INSTANCE_SIGNATURE:-}"
    if [ -z "$sig" ]; then
      newest=$(ls -td "$runtime"/hypr/*/ 2>/dev/null | head -1) || true
      [ -n "$newest" ] && sig=$(basename "$newest")
    fi
    if [ -n "$sig" ]; then
      HYPRLAND_INSTANCE_SIGNATURE="$sig" XDG_RUNTIME_DIR="$runtime" \
        /run/current-system/sw/bin/hyprctl dispatch \
        'hl.dsp.dpms({ action = "enable" })' >/dev/null 2>&1 || true
    fi
    exit 0
  '';
in
{
  options.features.sunshine = {
    enable = mkEnableOption "Sunshine desktop streaming host (for Moonlight clients)";

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Open the ports Sunshine needs. It is not one port: 47984/47989/48010
        TCP and 47998-48000/48002/48010 UDP, which is why this defers to
        upstream's own option rather than listing them here and drifting.

        Sunshine's web UI (47990) is HTTPS with a self-signed certificate and
        its own login, set on first visit. Leave this on only on a network
        where that is an acceptable front door.
      '';
    };

    wakeDisplay = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Turn the display back on when a client connects.

        Sunshine streams what the compositor renders to the monitor, so a
        screen that has been switched off produces a black stream and a
        completely clean log -- CLIENT CONNECTED, capture on the correct
        monitor, encoder running, no errors. Nothing distinguishes "the
        picture is dark" from "the picture is missing", which makes it an
        expensive half hour to diagnose.

        Sunshine cannot wake an output on its own, and it will not be woken by
        the client's input either, so without this every session that starts
        while the screen is off is a black one.

        Implemented as global_prep_cmd, not per-application, so it covers
        every entry including any still defined in the web UI's own apps
        list. Hyprland only.
      '';
    };

    webOrigins = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "https://192.168.1.75:47990" "https://myhost:47990" ];
      description = ''
        Origins allowed to use Sunshine's web UI, as scheme://host:port.

        Sunshine trusts only localhost, 127.0.0.1 and [::1] by default and
        refuses every POST from anywhere else with

          CSRF Protection Error
          The request was blocked by CSRF protection.

        That includes the request that creates the first username and
        password, so reaching the UI across the LAN is not merely restricted
        -- the page loads and nothing on it can be submitted. Every host that
        is administered from another machine needs its own address here.

        Include the port: the browser sends it in the Origin header, so
        "https://host" does not match "https://host:47990".

        Setting this has a side effect worth knowing, and it comes from
        upstream's module rather than from here: Sunshine is only handed a
        config file when some setting differs from the default, and that file
        lives in the Nix store, read-only. So as soon as this list is
        non-empty the web UI's Configuration tab can no longer save --
        settings belong in this repository from then on. Credentials and
        client pairings are not affected; those live in
        ~/.config/sunshine/sunshine_state.json, which stays writable.
      '';
    };
  };


  config = mkIf cfg.enable {
    services.sunshine = {
      enable = true;
      inherit (cfg) openFirewall;

      # KMS capture is off, and this is not a default worth revisiting here.
      #
      # Upstream's module offers capSysAdmin because KMS capture needs it, and
      # KMS capture is the only path to a hardware encoder for most GPUs. On
      # the NVIDIA proprietary driver it is not a path at all: nvidia-drm
      # enumerates no scanout planes with a framebuffer, so kmsgrab returns an
      # empty monitor list even holding CAP_SYS_ADMIN (verified on p510 --
      # "-------- Start of KMS monitor list --------" immediately followed by
      # the end marker, no error in between). Sunshine then reports "Unable to
      # initialize capture method" and exits.
      #
      # It is also actively harmful with the package built below: cudaSupport
      # makes $out/bin/sunshine a wrapper script, and a file capability on a
      # shell script is a trap rather than a feature.
      #
      # Wayland screencopy is what actually captures here, and it needs no
      # privilege at all.
      capSysAdmin = false;

      # Build with CUDA, or NVENC is compiled out and cannot be reached (#1588).
      #
      # p510 streamed 1440p on libx264 while an RTX 3070 Ti idled, and the
      # cause is upstream packaging, not configuration. nixpkgs takes
      # `cudaSupport ? config.cudaSupport`, which is false by default, and
      # passes -DSUNSHINE_ENABLE_CUDA=false. That undefines SUNSHINE_BUILD_CUDA,
      # and every CUDA encode path in Sunshine sits behind that #ifdef --
      # including the one in wlgrab's wlr_vram_t::make_avcodec_encode_device.
      # With the block compiled out the function falls through and returns a
      # plain avcodec_encode_device_t: the *software* converter. So ffmpeg
      # still offers h264_nvenc, Sunshine still creates it, and then the
      # software sws_scale in front of it fails on the dmabuf frame:
      #
      #   Info:  Creating encoder [h264_nvenc]
      #   Error: Couldn't scale frame: Invalid argument
      #   Info:  Encoder [nvenc] failed
      #   Info:  Found H.264 encoder: libx264 [software]
      #
      # That error is the whole bug, and it is why the earlier attempts missed:
      # neither the capture method nor the loader can affect it. The binary
      # simply had no CUDA in it -- 0 cuda symbols before, 3989 after.
      #
      # With this the log reads "Found H.264 encoder: h264_nvenc [nvenc]" and
      # "Found HEVC encoder: hevc_nvenc [nvenc]". AV1 is still rejected, which
      # is the Ampere card and not this setting.
      #
      # This also supersedes the DT_RUNPATH patch that #1588 first landed:
      # nixpkgs' own cudaSupport path already adds autoAddDriverRunpath, and
      # with capSysAdmin off there is no AT_SECURE to defeat LD_LIBRARY_PATH
      # in the first place.
      #
      # Unconditional because p510 is the only host that enables this module
      # and it is NVIDIA. A non-NVIDIA host would pull the CUDA toolkit for
      # nothing; gate it then, not now.
      package = pkgs.sunshine.override { cudaSupport = true; };

      settings =
        # Comma-separated, no spaces, as the option's own parser expects; an
        # entry it cannot read is dropped with "Invalid 'csrf_allowed_origins'
        # entry rejected" and the origin stays blocked.
        lib.optionalAttrs (cfg.webOrigins != [ ])
          {
            csrf_allowed_origins = lib.concatStringsSep "," cfg.webOrigins;
          }
        # A JSON array of do/undo pairs, which is why this is built with
        # toJSON rather than written out by hand. No undo: the screen is left
        # on after a session, because a host that someone also sits at should
        # not have its monitor switched off by a remote disconnect.
        // lib.optionalAttrs cfg.wakeDisplay {
          global_prep_cmd = builtins.toJSON [
            {
              "do" = "${wakeDisplayScript}";
              undo = "";
              elevated = false;
            }
          ];
        };

      # Start with the session rather than waiting for someone to run it.
      # Pointless without autologin on a headless-reboot host; harmless with.
      autoStart = true;
    };
  };
}
