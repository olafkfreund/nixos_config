{ nixpkgs, keyring, scenario, nonce }:
let
  pkgs = import nixpkgs { };
  keyringPath = builtins.storePath keyring;
  python = pkgs.python3.withPackages (ps: [ ps.dbus-next ps.cryptography ]);
in
pkgs.runCommand "gnome-keyring-unlock-queue-${scenario}-${nonce}"
{
  nativeBuildInputs = [ pkgs.dbus python ];
} ''
  mkdir -m 700 home runtime
  export HOME="$PWD/home" XDG_RUNTIME_DIR="$PWD/runtime"
  dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- ${python}/bin/python3 ${./test-gnome-keyring-unlock-queue.py} ${keyringPath} ${scenario} "$PWD/daemon.log" > result || true
  if test -f daemon.log; then cat daemon.log; fi
  if ! grep -Ex 'result=(ABORT|HANG|OK|INCONCLUSIVE)' result > "$out"; then
    printf 'result=INCONCLUSIVE\n' > "$out"
  fi
''
