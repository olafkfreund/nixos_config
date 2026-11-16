# Gate for #2973: behaviour of the T3 Code Omarchy theme activation script.
{ pkgs }:
let
  mkScript = import ../hosts/common/nixos/t3code-theme-script.nix { inherit pkgs; };
  tools = pkgs.lib.makeBinPath [ pkgs.coreutils pkgs.gnugrep pkgs.jq ];

  # Stubs read their behaviour from $CASE/cfg and log their arguments to $CASE/calls.
  publisher = pkgs.writeShellScript "omarchy-theme-set-t3code" ''
    . "$CASE/cfg"
    echo "publisher" >> "$CASE/calls"
    exit "''${PUB_EXIT:-0}"
  '';
  t3 = pkgs.writeShellScript "t3" ''
    . "$CASE/cfg"
    echo "t3 $*" >> "$CASE/calls"
    case "''${T3_MODE:-ok}" in
      fail) echo "first line"; echo "second line"; exit 1 ;;
      hang) trap "" TERM; exec sleep 60 ;;
    esac
    # theme set X --base-dir D
    mkdir -p "$5/userdata"
    echo "{\"defaultTheme\":\"$3\"}" > "$5/userdata/settings.json"
  '';

  stubs = withT3: pkgs.runCommand "t3code-stubs" { } ''
    mkdir -p $out
    ln -s ${publisher} $out/omarchy-theme-set-t3code
    ${if withT3 then "ln -s ${t3} $out/t3" else ""}
  '';

  full = mkScript { binPath = "${stubs true}:${tools}"; timeoutSecs = 2; killSecs = 1; };
  noT3 = mkScript { binPath = "${stubs false}:${tools}"; timeoutSecs = 2; killSecs = 1; };
in
pkgs.runCommand "t3code-theme"
{
  nativeBuildInputs = [ pkgs.shellcheck pkgs.coreutils pkgs.gnugrep pkgs.jq ];
} ''
  shellcheck ${full}

  fail() { echo "FAIL case $CASE_NAME: $*" >&2; echo "--- stderr:" >&2; cat "$CASE/err" >&2; exit 1; }
  has() { grep -qF -- "$2" "$1" || fail "$1 lacks '$2'"; }
  lacks() { ! grep -qF -- "$2" "$1" || fail "$1 has '$2'"; }

  # new_case NAME, then fixtures, then run SCRIPT.
  new_case() {
    CASE_NAME=$1
    export CASE=$PWD/case-$1
    mkdir -p "$CASE/home" "$CASE/tmp"
    : > "$CASE/cfg"; : > "$CASE/calls"
  }
  stage() { # staged palette; $1 = content
    mkdir -p "$CASE/home/.local/state/omarchy/current/theme"
    printf '%s' "$1" > "$CASE/home/.local/state/omarchy/current/theme/t3code.json"
  }
  fixture_theme() {
    mkdir -p "$CASE/home/.t3/userdata/themes"; echo '{}' > "$CASE/home/.t3/userdata/themes/omarchy.json"
  }
  settings() { mkdir -p "$CASE/home/.t3/userdata"; echo "{\"defaultTheme\":\"$1\"}" > "$CASE/home/.t3/userdata/settings.json"; }
  run() {
    rc=0
    env -i HOME="$CASE/home" TMPDIR="$CASE/tmp" CASE="$CASE" PATH=${pkgs.coreutils}/bin \
      ${pkgs.bash}/bin/bash "$1" > "$CASE/out" 2> "$CASE/err" || rc=$?
    [ "$rc" = 0 ] || fail "exit $rc"
  }

  new_case 1; run ${full}
  has $CASE/err "no Omarchy palette"; lacks $CASE/calls "publisher"; lacks $CASE/calls "t3 "

  new_case 2; stage '{}'; fixture_theme; echo 'PUB_EXIT=1' > $CASE/cfg; run ${full}
  has $CASE/err "publisher exited 1"; lacks $CASE/calls "t3 "

  new_case 3; stage '{"a":"{{ x }}"}'; fixture_theme; run ${full}
  has $CASE/err "palette has unresolved colours"; has $CASE/calls "t3 theme set omarchy"

  new_case 4; stage '{"a":"{{ x }}"}'; run ${full}
  has $CASE/err "theme omarchy not published"; lacks $CASE/calls "t3 "

  new_case 5; stage '{}'; fixture_theme; run ${full}
  has $CASE/calls "t3 theme set omarchy --base-dir $CASE/home/.t3"
  has $CASE/home/.t3/userdata/settings.json omarchy

  new_case 6; stage '{}'; fixture_theme; settings ember; run ${full}
  has $CASE/calls "t3 theme set omarchy"

  new_case 7; stage '{}'; fixture_theme; settings omarchy; run ${full}
  lacks $CASE/calls "t3 "

  new_case 8; stage '{}'; fixture_theme; echo 'T3_MODE=fail' > $CASE/cfg; run ${full}
  has $CASE/err "exited 1"
  has $CASE/err "t3code-theme: first line"; has $CASE/err "t3code-theme: second line"

  new_case 9; stage '{}'; fixture_theme; echo 'T3_MODE=hang' > $CASE/cfg
  SECONDS=0; run ${full}
  [ "$SECONDS" -le 5 ] || fail "took $SECONDS s"
  has $CASE/err "exited 137"
  [ -z "$(ls -A $CASE/tmp)" ] || fail "temp file left behind"

  new_case 10; stage '{}'; run ${noT3}
  has $CASE/err "t3 not found"; [ ! -e $CASE/home/.t3 ] || fail ".t3 was created"

  touch $out
''
