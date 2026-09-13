{ lib
, buildGoModule
, go_1_27
, fetchFromGitHub
, makeWrapper
, sqlite
, libsecret
, runCommand
}:
# Google Messages in the Omarchy bar (MarcFord/gmessages-omarchy-plugin).
# `gmessagesd` is the daemon; `passthru.plugin` is the QML bar widget, which
# does nothing without the daemon running. Bump against:
#   gh api repos/MarcFord/gmessages-omarchy-plugin/tags --jq '.[].name'
(buildGoModule.override { go = go_1_27; }) (finalAttrs: {
  pname = "gmessagesd";
  version = "1.2.1";

  src = fetchFromGitHub {
    owner = "MarcFord";
    repo = "gmessages-omarchy-plugin";
    rev = "v${finalAttrs.version}";
    hash = "sha256-fONYQmLXf2GJqaDB1fsuT4yqQoGcjy2TYUPJD3MVXTo=";
  };

  vendorHash = "sha256-7rXWjhI7lOrWoHhIWUyFyDajncv4JyifcgBF6capN64=";

  subPackages = [ "cmd/gmessagesd" ];
  ldflags = [ "-X main.version=${finalAttrs.version}" ];

  nativeBuildInputs = [ makeWrapper ];

  # Pairing reads Chrome's cookie DB with the sqlite3 CLI and its key with
  # secret-tool. ffmpeg/qrencode are called from the QML side, not here.
  postInstall = ''
    wrapProgram $out/bin/gmessagesd \
      --prefix PATH : ${lib.makeBinPath [ sqlite libsecret ]}
  '';

  passthru.plugin = runCommand "gmessages-omarchy-plugin-${finalAttrs.version}" { } ''
    mkdir -p $out
    cp ${finalAttrs.src}/{Widget.qml,Panel.qml,GmClient.qml,Avatar.qml,Model.js,manifest.json} $out/
  '';

  meta = {
    description = "Google Messages daemon for the Omarchy bar plugin";
    homepage = "https://github.com/MarcFord/gmessages-omarchy-plugin";
    license = lib.licenses.mit;
    mainProgram = "gmessagesd";
    platforms = lib.platforms.linux;
  };
})
