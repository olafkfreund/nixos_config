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
  version = "0.30.0";

  src = fetchFromGitHub {
    owner = "google-gemini";
    repo = "gemini-cli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-+w4w1cftPSj0gJ23Slw8Oexljmu0N/PZWH4IDjw75rs=";
  };

  npmDepsHash = "sha256-Nkd5Q2ugRqsTqaFbCSniC3Obl++uEjVUmoa8MVT5++8=";

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

  preConfigure = ''
    mkdir -p packages/generated
    echo "export const GIT_COMMIT_INFO = { commitHash: '${finalAttrs.src.rev}' };" > packages/generated/git-commit.ts
  '';

  postPatch = ''
    # Remove node-pty and native optional dependencies from package.json
    ${jq}/bin/jq 'del(.optionalDependencies."node-pty", .optionalDependencies."@lydell/node-pty", .optionalDependencies."@lydell/node-pty-darwin-arm64", .optionalDependencies."@lydell/node-pty-darwin-x64", .optionalDependencies."@lydell/node-pty-linux-x64", .optionalDependencies."@lydell/node-pty-win32-arm64", .optionalDependencies."@lydell/node-pty-win32-x64", .optionalDependencies."keytar")' package.json > package.json.tmp && mv package.json.tmp package.json

    # Remove node-pty and native optional dependencies from packages/core/package.json
    ${jq}/bin/jq 'del(.optionalDependencies."node-pty", .optionalDependencies."@lydell/node-pty", .optionalDependencies."@lydell/node-pty-darwin-arm64", .optionalDependencies."@lydell/node-pty-darwin-x64", .optionalDependencies."@lydell/node-pty-linux-x64", .optionalDependencies."@lydell/node-pty-win32-arm64", .optionalDependencies."@lydell/node-pty-win32-x64", .optionalDependencies."keytar")' packages/core/package.json > packages/core/package.json.tmp && mv packages/core/package.json.tmp packages/core/package.json

    # Fix ripgrep path for SearchText; ensureRgPath() on its own may return the path to a dynamically-linked ripgrep binary without required libraries
    substituteInPlace packages/core/src/tools/ripGrep.ts \
      --replace-fail "await ensureRgPath();" "'${lib.getExe ripgrep}';"

    # Disable auto-update and update notifications by changing defaults in settingsSchema
    # (API changed in 0.26.0 from disableAutoUpdate to enableAutoUpdate)
    sed -i '/enableAutoUpdate: {/,/default: true/ s/default: true/default: false/' packages/cli/src/config/settingsSchema.ts
    sed -i '/enableAutoUpdateNotification: {/,/default: true/ s/default: true/default: false/' packages/cli/src/config/settingsSchema.ts
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/{bin,share/gemini-cli}

    npm prune --omit=dev
    rm node_modules/shell-quote/print.py # remove python demo to prevent python from getting into the closure
    cp -r node_modules $out/share/gemini-cli/

    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-core
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-a2a-server
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-sdk
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-test-utils
    rm -f $out/share/gemini-cli/node_modules/gemini-cli-vscode-ide-companion
    cp -r packages/cli $out/share/gemini-cli/node_modules/@google/gemini-cli
    cp -r packages/core $out/share/gemini-cli/node_modules/@google/gemini-cli-core
    cp -r packages/a2a-server $out/share/gemini-cli/node_modules/@google/gemini-cli-a2a-server
    cp -r packages/sdk $out/share/gemini-cli/node_modules/@google/gemini-cli-sdk

    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-core/dist/docs/CONTRIBUTING.md

    ln -s $out/share/gemini-cli/node_modules/@google/gemini-cli/dist/index.js $out/bin/gemini
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
