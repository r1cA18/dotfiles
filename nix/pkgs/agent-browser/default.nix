{
  buildNpmPackage,
  fetchurl,
  lib,
  stdenv,
}:
buildNpmPackage rec {
  pname = "agent-browser";
  version = "0.17.1";

  src = fetchurl {
    url = "https://registry.npmjs.org/agent-browser/-/agent-browser-${version}.tgz";
    hash = "sha512-KNV+6F3nYStxgTrsdcfMBsxtLdnaUu2NTuQ9EL8CvnYUgAzdoYztYVJzkr1KbconGEyLdSgXZedSsKw0TPiL/g==";
  };
  sourceRoot = "package";
  npmDepsHash = "sha256-kUOLY3qidvG+HSP/UUjQKO2WsX7N54vZXBzcsalwrvA=";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmFlags = [
    "--legacy-peer-deps"
  ];

  npmInstallFlags = [
    "--omit=dev"
    "--ignore-scripts"
    "--legacy-peer-deps"
  ];
  npmPackFlags = [
    "--ignore-scripts"
  ];

  dontNpmBuild = true;

  postInstall = ''
    bin_dir="$out/lib/node_modules/agent-browser/bin"

    case "${stdenv.hostPlatform.system}" in
      aarch64-darwin) keep_binary="agent-browser-darwin-arm64" ;;
      x86_64-darwin) keep_binary="agent-browser-darwin-x64" ;;
      aarch64-linux) keep_binary="agent-browser-linux-arm64" ;;
      x86_64-linux) keep_binary="agent-browser-linux-x64" ;;
      *)
        echo "unsupported agent-browser platform: ${stdenv.hostPlatform.system}" >&2
        exit 1
        ;;
    esac

    find "$bin_dir" -maxdepth 1 -type f -name 'agent-browser-*' ! -name "$keep_binary" -delete
    chmod +x "$bin_dir/$keep_binary"
  '';

  installCheckPhase = ''
    runHook preInstallCheck
    HOME="$TMPDIR" "$out/bin/agent-browser" --help >/dev/null
    runHook postInstallCheck
  '';

  meta = with lib; {
    description = "Headless browser automation CLI for AI agents";
    homepage = "https://github.com/vercel-labs/agent-browser";
    license = licenses.asl20;
    mainProgram = "agent-browser";
    platforms = platforms.unix;
  };
}
