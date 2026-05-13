{ lib
, buildNpmPackage
, fetchFromGitHub
, nix-update-script
, ripgrep
, jq
, pkg-config
, libsecret
, nodejs_22
, stdenv
, darwin
,
}:

buildNpmPackage (finalAttrs: {
  pname = "gemini-cli";
  version = "0.42.0";

  src = fetchFromGitHub {
    owner = "google-gemini";
    repo = "gemini-cli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-QYSzJdyjJ5SvPkI/uf/wu8MdM76W+djai6zD38IJpos=";
  };

  npmDepsHash = "sha256-hKNEJ/MAseYs8WLr36h40pYv+5nef8EPhZIfmPKYJPY=";

  nodejs = nodejs_22;

  nativeBuildInputs = [
    jq
    pkg-config
  ] ++ lib.optionals stdenv.hostPlatform.isDarwin [
    darwin.cctools
  ];

  buildInputs = [
    ripgrep
    libsecret
  ];

  # `scripts/generate-git-commit-info.js` is invoked very early by the
  # `bundle` script and calls `git` — not available in the sandbox. Pre-
  # generate the file at both locations the script writes to (it moved
  # between 0.34 and 0.41), so the script becomes a no-op.
  preConfigure = ''
    mkdir -p packages/cli/src/generated packages/core/src/generated packages/generated
    for f in packages/cli/src/generated/git-commit.ts \
             packages/core/src/generated/git-commit.ts \
             packages/generated/git-commit.ts; do
      echo "export const GIT_COMMIT_INFO = { commitHash: '${finalAttrs.src.rev}' };" > "$f"
    done
  '';

  postPatch = ''
    # Drop node-pty and friends — they're native modules we can't build,
    # and gemini-cli already falls back gracefully when they're absent.
    ${jq}/bin/jq 'del(
      .optionalDependencies."node-pty",
      .optionalDependencies."@lydell/node-pty",
      .optionalDependencies."@lydell/node-pty-darwin-arm64",
      .optionalDependencies."@lydell/node-pty-darwin-x64",
      .optionalDependencies."@lydell/node-pty-linux-x64",
      .optionalDependencies."@lydell/node-pty-win32-arm64",
      .optionalDependencies."@lydell/node-pty-win32-x64",
      .optionalDependencies."keytar"
    )' package.json > package.json.tmp && mv package.json.tmp package.json

    ${jq}/bin/jq 'del(
      .optionalDependencies."node-pty",
      .optionalDependencies."@lydell/node-pty",
      .optionalDependencies."@lydell/node-pty-darwin-arm64",
      .optionalDependencies."@lydell/node-pty-darwin-x64",
      .optionalDependencies."@lydell/node-pty-linux-x64",
      .optionalDependencies."@lydell/node-pty-win32-arm64",
      .optionalDependencies."@lydell/node-pty-win32-x64",
      .optionalDependencies."keytar"
    )' packages/core/package.json > packages/core/package.json.tmp && mv packages/core/package.json.tmp packages/core/package.json

    # Fix ripgrep path for SearchText; ensureRgPath() on its own may return
    # a dynamically-linked binary without the required libraries.
    substituteInPlace packages/core/src/tools/ripGrep.ts \
      --replace-fail "await ensureRgPath();" "'${lib.getExe ripgrep}';"

    # Disable auto-update and notifications (we deliver new versions via
    # the /update-gemini slash command, not in-process self-updates).
    sed -i '/enableAutoUpdate:/,/default: true/ s/default: true/default: false/' \
      packages/cli/src/config/settingsSchema.ts
    sed -i '/enableAutoUpdateNotification:/,/default: true/ s/default: true/default: false/' \
      packages/cli/src/config/settingsSchema.ts

    # Belt-and-braces — also pin the runtime checks to false so even if
    # someone's existing settings.json has the keys set true, no update
    # action fires.
    substituteInPlace packages/cli/src/utils/handleAutoUpdate.ts \
      --replace-fail "if (!settings.merged.general.enableAutoUpdateNotification) {" "if (false) {" \
      --replace-fail "settings.merged.general.enableAutoUpdate," "false," \
      --replace-fail "!settings.merged.general.enableAutoUpdate" "!false"
  '';

  # Use upstream's `bundle` script — it produces a single esbuild output
  # rather than building each workspace package, which avoids the
  # devtools / workspace-order TS errors that hit us on 0.34→0.41.
  npmBuildScript = "bundle";

  # Keep python (a transitive of npm) out of the closure.
  disallowedReferences = [
    finalAttrs.npmDeps
    finalAttrs.nodejs.python
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,share}
    cp -r bundle $out/share/gemini-cli

    # bundle/docs/CONTRIBUTING.md is a symlink into /build/source/ and
    # trips the noBrokenSymlinks postFixup check. Drop it — docs aren't
    # runtime-relevant.
    rm -f $out/share/gemini-cli/docs/CONTRIBUTING.md

    # Reduce closure: drop devDependencies + non-optional bundled deps.
    # Only optionalDependencies (the platform-specific native bits we
    # didn't already strip in postPatch) remain on disk.
    ${jq}/bin/jq '.dependencies = {} | del(.devDependencies) | del(.workspaces)' \
      package.json > package.json.tmp && mv package.json.tmp package.json
    npm prune --omit=dev
    rm -rf node_modules/.bin

    ln -s $out/share/gemini-cli/gemini.js $out/bin/gemini
    chmod +x "$out/bin/gemini"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "AI agent that brings the power of Gemini directly into your terminal";
    homepage = "https://github.com/google-gemini/gemini-cli";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with lib.maintainers; [
      xiaoxiangmoe
      FlameFlag
      taranarmo
    ];
    platforms = lib.platforms.all;
    mainProgram = "gemini";
  };
})
