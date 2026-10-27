{ lib
, stdenvNoCC
, fetchFromGitHub
, python3
, hyprland
, util-linux
, wl-clipboard
, coreutils
, xdg-utils
, dbus
, bash
, glib
, openssl
, at-spi2-core
, gobject-introspection
, jq
}:
# Omapop (jondkinney/omapop): PopClip-style selection action bar for the
# Omarchy shell. Upstream hardcodes /usr/bin tools and a /usr/bin:/bin PATH, so
# this points every one of them at store paths and a NixOS PATH. It also turns
# directoryRefresh off, which upstream enables by default.
# qt612-color.patch is upstream PR #10 (Qt 6.12 Color fix); drop it once an
# upstream bump contains it.
# Bump against: gh api repos/jondkinney/omapop/commits --jq '.[0].sha'
let
  py = python3.withPackages (p: [ p.pyyaml p.pygobject3 ]);
  bin = pkg: name: "${lib.getBin pkg}/bin/${name}";
  path = "/run/current-system/sw/bin:/etc/profiles/per-user/olafkfreund/bin:/usr/bin:/bin";
in
stdenvNoCC.mkDerivation {
  pname = "omapop-plugin";
  version = "0.4.11";

  src = fetchFromGitHub {
    owner = "jondkinney";
    repo = "omapop";
    rev = "7d6b1aa0e5cb14f7d8bf24f9e78ffcad5deb00f7";
    hash = "sha256-0r5UBaCOkO8mdXGgy8QVnRHsnkIWohndGVnguwQnHmA=";
  };

  patches = [ ./qt612-color.patch ];

  nativeBuildInputs = [ jq ];

  dontBuild = true;

  postPatch = ''
    substituteInPlace Service.qml \
      --replace-fail '/usr/bin/python3' '${py}/bin/python3' \
      --replace-fail '/usr/bin/hyprctl' '${bin hyprland "hyprctl"}' \
      --replace-fail '/usr/bin/setpriv' '${bin util-linux "setpriv"}' \
      --replace-fail '/usr/bin/wl-paste' '${bin wl-clipboard "wl-paste"}' \
      --replace-fail '/usr/bin/echo' '${bin coreutils "echo"}' \
      --replace-fail '/usr/bin/mkdir' '${bin coreutils "mkdir"}' \
      --replace-fail '/usr/bin/xdg-open' '${bin xdg-utils "xdg-open"}' \
      --replace-fail '/usr/bin/dbus-send' '${bin dbus "dbus-send"}' \
      --replace-fail '"/usr/bin/bash"' '"${bin bash "bash"}"' \
      --replace-fail 'PATH: "/usr/bin:/bin",' 'PATH: "${path}",' \
      --replace-fail 'env.PATH = "/usr/bin:/bin:/usr/sbin:/sbin"' 'env.PATH = "${path}"' \
      --replace-fail 'setting("directoryRefresh", true) !== false' 'setting("directoryRefresh", false) === true'

    substituteInPlace bin/omapop-native.py \
      --replace-fail "env['PATH'] = '/usr/bin:/bin'" "env['PATH'] = '${path}'" \
      --replace-fail '/usr/bin/setpriv' '${bin util-linux "setpriv"}' \
      --replace-fail '/usr/bin/xdg-open' '${bin xdg-utils "xdg-open"}' \
      --replace-fail '/usr/bin/bash' '${bin bash "bash"}'

    substituteInPlace bin/omapop-selection.py \
      --replace-fail '"/usr/bin/wl-paste"' '"${bin wl-clipboard "wl-paste"}"'

    substituteInPlace bin/omapop-clipboard.py \
      --replace-fail '"/usr/bin/wl-copy"' '"${bin wl-clipboard "wl-copy"}"'

    substituteInPlace bin/omapop-context.py \
      --replace-fail '"/usr/bin/gdbus"' '"${bin glib "gdbus"}"' \
      --replace-fail 'try:
        import gi
    ' 'try:
        os.environ.setdefault("GI_TYPELIB_PATH", "${at-spi2-core}/lib/girepository-1.0:${glib.out}/lib/girepository-1.0:${gobject-introspection.out}/lib/girepository-1.0")
        import gi
    '

    substituteInPlace bin/omapop_catalog.py \
      --replace-fail "'/usr/bin/openssl'" "'${bin openssl "openssl"}'"

    jq '.barWidget.defaults.directoryRefresh = false
      | (.barWidget.schema[] | select(.key == "directoryRefresh") | .defaultValue) = false' \
      manifest.json > manifest.json.new
    mv manifest.json.new manifest.json
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    for f in * .[!.]*; do
      case "$f" in
        tests|tools|preview.jpg|.gitattributes|.gitignore|.git) ;;
        *) cp -r --no-preserve=mode "$f" $out/ ;;
      esac
    done

    runHook postInstall
  '';

  meta = {
    description = "PopClip-style selection action bar plugin for the Omarchy shell";
    homepage = "https://github.com/jondkinney/omapop";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
