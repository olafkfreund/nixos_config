{ lib
, stdenvNoCC
, fetchFromGitHub
, python3
, android-tools
, scrcpy
, avahi
, systemd
, libnotify
, bash
}:
# OmaDroid (onelegdave/omadroid): Android mirroring from the Omarchy bar via
# scrcpy + adb. Upstream pins every tool to /usr/bin and verifies each path is
# root-owned and not group-writable, so this points it at store paths and lets
# the sticky, root-owned /nix/store directory pass that check.
# Bump against: gh api repos/onelegdave/omadroid/commits --jq '.[0].sha'
let
  bin = pkg: name: "${lib.getBin pkg}/bin/${name}";
  path = lib.makeBinPath [ android-tools systemd libnotify ];
in
stdenvNoCC.mkDerivation {
  pname = "omadroid-plugin";
  # v0.3.4 plus the upstream fix that restores local ADB startup.
  version = "0.3.4-unstable-2026-09-13";

  src = fetchFromGitHub {
    owner = "onelegdave";
    repo = "omadroid";
    rev = "704e8305964e9b6a390c4cd7d20fe10ac71db9ae";
    hash = "sha256-PMHjNCbxHDYP65k3hVoXsfK42rbmoFRGu1bpeYz8izI=";
  };

  dontBuild = true;

  # kdeconnect-cli, pacman and omarchy-launch-terminal stay on /usr/bin, which
  # does not exist here: KDE Connect is off on these hosts, and the Install
  # buttons would run pacman. Both simply report as unavailable.
  installPhase = ''
    runHook preInstall

    substituteInPlace safe_process.py \
      --replace-fail "STDOUT_LIMIT = 512 * 1024" "TOOLS.update({
        'adb': '${bin android-tools "adb"}',
        'scrcpy': '${bin scrcpy ".scrcpy-wrapped"}',
        'avahi-browse': '${bin avahi "avahi-browse"}',
        'busctl': '${bin systemd "busctl"}',
        'systemctl': '${bin systemd "systemctl"}',
        'systemd-run': '${bin systemd "systemd-run"}',
        'notify-send': '${bin libnotify "notify-send"}',
        'bash': '${bin bash "bash"}',
        'python3': '${bin python3 "python3"}'})
    STDOUT_LIMIT = 512 * 1024" \
      --replace-fail "info.st_mode & (0o022 |" \
        "info.st_mode & ((0o002 if directory and info.st_mode & stat.S_ISVTX else 0o022) |" \
      --replace-fail "path = '/usr/bin/' + target" "path = os.path.dirname(path) + '/' + target" \
      --replace-fail "'PATH': '/usr/bin'" "'PATH': '${path}'" \
      --replace-fail "'ADB': '/usr/bin/adb'" "'ADB': '${bin android-tools "adb"}'" \
      --replace-fail "/usr/share/scrcpy/scrcpy-server" "${scrcpy}/share/scrcpy/scrcpy-server"

    substituteInPlace Panel.qml \
      --replace-fail '"/usr/bin/python3"' '"${bin python3 "python3"}"' \
      --replace-fail '"PATH": "/usr/bin"' '"PATH": "${path}"'

    mkdir -p $out
    cp manifest.json Panel.qml phone_mirror.py safe_files.py safe_process.py LICENSE $out/

    runHook postInstall
  '';

  meta = {
    description = "Omarchy bar plugin for mirroring and controlling Android phones";
    homepage = "https://github.com/onelegdave/omadroid";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
