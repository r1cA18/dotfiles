{
  buildNpmPackage,
  fetchurl,
  lib,
  nodejs_24,
  callPackage,
  makeWrapper,
}:
let
  runtime = callPackage ./node-runtime.nix { };
in
buildNpmPackage rec {
  pname = "deepseek-harness";
  version = "0.2.1-rc.2";
  nodejs = nodejs_24;
  nativeBuildInputs = [ makeWrapper ];

  src = fetchurl {
    url = "https://registry.npmjs.org/@deepseek-ai/dsh/-/dsh-${version}.tgz";
    hash = "sha512-tvY+yhfKRifthbqPe/OK0AYxM5ZkvqfYq/jMYgJcEUxiRRL1Vwra3Ti5TB6AXgSWQdiPHYh/Vp6SJa9yHwMNuw==";
  };
  sourceRoot = "package";
  npmDepsHash = "sha256-ofqSx1tTyIwt2ukhWWuTrjZLa9wMrLPhRWPCL4Nb0YU=";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';
  dontNpmBuild = true;
  npmInstallFlags = [
    "--omit=dev"
    "--ignore-scripts"
  ];
  npmPackFlags = [ "--ignore-scripts" ];

  # The native loader recognizes official Node machine code. Nix-built Node
  # 22/24 failed its arm64 realm-getter check; keep a private pinned runtime.
  postInstall = ''
    rm "$out/bin/dsh"
    makeWrapper ${runtime}/bin/node "$out/bin/dsh" \
      --add-flags "$out/lib/node_modules/@deepseek-ai/dsh/lib/bin.js"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR/check-home"
    export DSH_HOME="$HOME/.dsh"
    mkdir -p "$HOME"
    "$out/bin/dsh" --version | grep -F '${version}'
    "$out/bin/dsh" --help >/dev/null
    "$out/bin/dsh" --profile headless --help >/dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "DeepSeek Harness plugin-based agent runtime";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    mainProgram = "dsh";
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
