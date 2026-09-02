# Sunshine (remote desktop streaming)

Last Updated: 2026-09-01

Sunshine streams a host's live Wayland session to a [Moonlight](https://moonlight-stream.org/)
client. It is enabled on **p510** only, via `features.sunshine` in
`modules/desktop/sunshine.nix`.

## Why not GNOME Remote Desktop

p510 used to be served over RDP by `gnome-remote-desktop`. That daemon is a GNOME
Shell component using GNOME's own screencast pipeline, so once Hyprland became
the session there was nothing on the other end of the connection. Sunshine
captures the compositor's output directly, which is compositor-agnostic, and
encodes on the GPU.

## Enabling it

```nix
features.sunshine = {
  enable = true;
  wakeDisplay = true;
  webOrigins = [
    "https://192.168.1.75:47990"
    "https://p510:47990"
    "https://p510.local:47990"
  ];
};
```

| Option | Default | Purpose |
| --- | --- | --- |
| `enable` | `false` | Turn the streaming host on |
| `openFirewall` | `true` | Open the Moonlight + web UI ports |
| `wakeDisplay` | `false` | Wake a DPMS-off output when a client connects |
| `webOrigins` | `[ ]` | Origins allowed to POST to the web UI |

## First-time setup

1. Browse to `https://<host>:47990` (self-signed certificate — accept it).
2. Create the admin username and password on the `/welcome` page.
3. Pair a Moonlight client; the PIN is entered in the web UI.

## Four traps, in the order you will hit them

### 1. It is a systemd *user* service

Upstream's module puts Sunshine in the user session because it needs the user's
Wayland socket, GPU device nodes and input devices. It therefore comes up when a
graphical session does and **not a moment sooner**.

On a host that reboots unattended, remote access depends on that session existing
with nobody at the keyboard — which is why p510 keeps autologin on while p620 and
razer do not.

!!! note "The hardening rules do not apply here"
    `DynamicUser`, `ProtectHome` and `ProtectSystem = "strict"` all assume a
    service that needs nothing of the user's session. Sandboxing this one to the
    level `CLAUDE.md` mandates is equivalent to switching it off, so the
    exception is recorded in the module rather than silently taken.

### 2. A connected stream that is solid black

Sunshine captures whatever the compositor puts on the monitor, so a DPMS-off
output streams as black — with a completely clean log: client connected, capture
on the right monitor, encoder running, no errors.

`wakeDisplay = true` fixes it with a `global_prep_cmd` that runs on connect.
Two details matter if you ever touch that script:

- Hyprland 0.56 config here is **Lua**. The dispatcher is
  `hl.dsp.dpms({ action = "enable" })`; `hyprctl dispatch "dpms on"` is a no-op.
- `hyprctl` must come from `/run/current-system/sw/bin`, not `pkgs.hyprland`.
  `omarchy-sole-hyprland.nix` puts the Hyprland that Nixarchy pins into the
  system profile, and that is the build actually running the session. nixpkgs
  carries a different version and this dispatcher API is version-sensitive.
- The script always exits `0`. Sunshine aborts the entire stream if a prep
  command fails, so a missing Hyprland must degrade to "no wake", never to
  "no streaming".

There is deliberately no `undo`: a host someone also sits at should not have its
monitor switched off by a remote disconnect.

### 3. "CSRF Protection Error" on the web UI

The web UI refuses cross-origin POSTs, so logging in from another machine fails
with a CSRF toast and nothing on the page can be submitted. Add the address to
`webOrigins`.

**Include the port.** The browser sends it in the `Origin` header, so
`https://p510` does not match `https://p510:47990`.

### 4. Any setting at all makes the web UI read-only

This comes from upstream's module, not from ours: Sunshine is only handed a
config file when some setting differs from the default, and that file lives in
the Nix store, read-only. As soon as `webOrigins` or `wakeDisplay` is set, the
web UI's **Configuration** tab can no longer save — settings belong in this
repository from then on.

Credentials and client pairings are unaffected; those live in
`~/.config/sunshine/sunshine_state.json`, which stays writable.

## Hardware encoding

Sunshine encodes on the RTX 3070 Ti, and getting there took one non-obvious
change ([#1588](https://github.com/olafkfreund/nixos_config/issues/1588)).

nixpkgs builds Sunshine with `cudaSupport ? config.cudaSupport`, false by
default, which passes `-DSUNSHINE_ENABLE_CUDA=false`. Every CUDA encode path in
Sunshine sits behind that `#ifdef`, including the one in wlgrab's
`wlr_vram_t::make_avcodec_encode_device`. Compiled out, the function falls
through to a plain `avcodec_encode_device_t` — the *software* converter. ffmpeg
still advertises `h264_nvenc`, Sunshine still creates it, and the software
`sws_scale` in front of it then fails on the dmabuf frame:

```text
Info:  Creating encoder [h264_nvenc]
Error: Couldn't scale frame: Invalid argument
Info:  Encoder [nvenc] failed
Info:  Found H.264 encoder: libx264 [software]
```

The module therefore builds `pkgs.sunshine.override { cudaSupport = true; }`.
The binary goes from 0 CUDA symbols to 3989, and the log reads:

```text
Info: Found H.264 encoder: h264_nvenc [nvenc]
Info: Found HEVC encoder: hevc_nvenc [nvenc]
```

AV1 is still rejected — that is Ampere, not this setting.

Two earlier theories were wrong and are recorded so they are not retried:

- **It is not `LD_LIBRARY_PATH` versus `AT_SECURE`.** That story was real but
  incidental: `capSysAdmin` does make `security.wrappers` build a wrapper, the
  process does run `AT_SECURE`, and the loader does drop `LD_LIBRARY_PATH`.
  Writing the driver directory into `DT_RUNPATH` removed the
  `Cannot load libcuda.so.1` errors and changed nothing else — the encoder was
  still software, because the CUDA code was never in the binary.
- **`capSysAdmin` is not worth keeping.** KMS capture is the only reason for
  it, and on the NVIDIA proprietary driver kmsgrab enumerates no scanout plane
  with a framebuffer. The monitor list comes back empty even while holding
  `CAP_SYS_ADMIN`, and Sunshine exits with "Unable to initialize capture
  method". The option has been removed; capture is Wayland screencopy, which
  needs no privilege.
