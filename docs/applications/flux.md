# Flux (phone link)

Last Updated: 2026-11-13

Flux connects the desktop session to an Android phone (`fluxd`, `flux-cli`, `flux-gui` and the Omarchy bar plugin) from the `nixarchy-flux` flake input. It is enabled on **p620** and **razer** via `features.flux` in `modules/desktop/flux.nix`.

## What `features.flux` enables

`modules/desktop/flux.nix` uses the upstream NixOS + Home Manager hybrid so the daemon and shell plugin live in the user session while system packages and udev rules are installed at the host level:

- **NixOS (`inputs.nixarchy-flux.nixosModules.default`):**
  - Installs the `flux` packages, runtime tools and udev rules (`services.flux.enable = true`).
  - Sets `users = [ ]` so the NixOS module does not define a competing `fluxd.service` user unit.
  - Leaves `openFirewall = false`, `approve.services = [ ]` (no PAM fingerprint approval) and `webcam.enable = false`.
- **Home Manager (`inputs.nixarchy-flux.homeManagerModules.default`):**
  - Owns the `fluxd.service` user unit (wanted by `graphical-session.target`).
  - Enables the Omarchy shell plugin (`plugin.enable = true`), copied as a real folder to `~/.config/omarchy/plugins/flux` (not a symlink, because `fluxd` plugin sync refuses symlinks).
  - Leaves the browser extension disabled (`browser.enable = false`).
- **Avahi:** Upstream's `lib.mkDefault` Avahi settings apply unless overridden. On **p620**, the host's explicit `allow-interfaces = [ "enp1s0" ]` pin wins. On **razer**, Avahi is filtered on untrusted networks by the guard below.

## Hardening exceptions

- **`fluxd.service` (systemd user unit):** `fluxd` serves the user's files, clipboard and phone link inside the graphical session. `DynamicUser` and `ProtectHome` would break access to the user session and `~/.local/share/flux`, and `ProtectSystem = "strict"` requires mount namespacing that user units lack. `NoNewPrivileges` is also omitted because `fluxd` runs user-defined phone commands (`commands.run`) that may invoke `sudo` or other setuid wrappers. The module adds `LockPersonality = true`.
- **`flux-guard.service` and `flux-guard-sync.service` (system units on razer):** Both units omit `DynamicUser` because they need `CAP_NET_ADMIN` in the host network namespace to load `nftables` rules (`AF_NETLINK`) and query active NetworkManager connections (`AF_UNIX`). They enforce `CapabilityBoundingSet = [ "CAP_NET_ADMIN" ]`, `NoNewPrivileges = true`, `ProtectSystem = "strict"`, `ProtectHome = true`, `PrivateTmp = true`, `ReadWritePaths = [ "/run" ]`, `RestrictAddressFamilies = [ "AF_NETLINK" "AF_UNIX" ]` and `ProtectKernelModules = true`.

## Trusted-networks guard (`razer`)

`fluxd` listens on all addresses (control TCP `12100–12108`, discovery UDP `12100`, payload TCP `12070–12099`), and `razer` runs with the NixOS firewall disabled while roaming between home and guest Wi-Fi on the same interface (`wlp3s0`).

When `features.flux.trustedConnections` is set to a list of NetworkManager connection UUIDs (`null` on **p620**, where no guard is loaded):

- `flux-guard.service` atomically loads the `inet flux_guard` nftables table before `network-pre.target`, with `@trusted` initially holding `lo` and `tailscale0`.
- `flux-guard-sync.service` and a NetworkManager dispatcher script (`up`, `down`, `pre-down`, `dhcp4-change`, `connectivity-change`) serialize on `/run/flux-guard.lock`, query `nmcli -t -f UUID,DEVICE connection show --active`, and atomically rebuild `@trusted` with `lo`, `tailscale0` and any active device whose connection UUID is in `trustedConnections`.

### What is blocked on untrusted networks

- **Inbound:** New connections (`ct state new`) to TCP `12070–12108` and UDP `12100` are dropped. Replies to `razer`'s own outbound connections still pass.
- **Outbound:** All mDNS packets (`udp dport 5353` and `udp sport 5353`) and Flux's UDP `12100` identity broadcasts are dropped, so neither Flux nor GNOME Remote Desktop announces `razer`.
- **Side effects on untrusted networks:** `.local` mDNS name resolution and printer/service discovery are disabled while connected to an untrusted network.
- **Tailscale:** `tailscale0` is always in `@trusted`, so Flux works in both directions over Tailscale on any network.

### Adding a trusted network

UUIDs are used instead of SSIDs so network names stay out of the repository.

1. Find the NetworkManager connection UUID on the host:

   ```bash
   nmcli -t -f NAME,UUID connection show
   ```

2. Add the UUID to `features.flux.trustedConnections` in `hosts/razer/configuration.nix`:

   ```nix
   features.flux = {
     enable = true;
     trustedConnections = [
       "2480c26b-7797-49e1-8a9f-af6bccc6d77c"
     ];
   };
   ```

## Manual setup steps

1. **Enable the Omarchy shell plugin:** Run once from the desktop session on each host:

   ```bash
   flux-cli setup
   ```

2. **Pair `razer` from the phone:** While on a trusted network (or Tailscale), open the Flux Android app and pair with `razer` once. Pairings and identity keys persist in `~/.local/share/flux/` (`devices.json`, `certificate.pem`, `privateKey.pem`).
3. **Add the phone's Tailscale address:** Add the phone's Tailscale IP as an extra address in Flux so `p620` and `razer` can reach the phone directly over `tailscale0` when off the home LAN or on an untrusted Wi-Fi network.
