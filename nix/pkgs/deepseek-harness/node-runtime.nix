{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenv,
  stdenvNoCC,
}:
let
  sources = {
    aarch64-darwin = {
      platform = "darwin-arm64";
      hash = "sha256-QOVgfl7LPbkZJyN3baLXXZZiYPx0p6nnMcG9Z92pa8g=";
    };
    x86_64-darwin = {
      platform = "darwin-x64";
      hash = "sha256-nlsmRM8Qe++2rvymdrltMpa8EBOAlvAi7TeNYjPtgfQ=";
    };
    aarch64-linux = {
      platform = "linux-arm64";
      hash = "sha256-NRVgPiSHh5o5vHVxbxoq/9AnUAxkulDoRc9yyzMhkBM=";
    };
    x86_64-linux = {
      platform = "linux-x64";
      hash = "sha256-hV1YH4pOsagRfjQm3iX+AncFkv68+zE2mu4f+/7p6Ow=";
    };
  };
  source =
    sources.${stdenv.hostPlatform.system} or (throw "Unsupported DeepSeek Harness Node platform");
in
stdenvNoCC.mkDerivation rec {
  pname = "deepseek-harness-node";
  version = "24.20.0";
  src = fetchurl {
    url = "https://nodejs.org/dist/v${version}/node-v${version}-${source.platform}.tar.gz";
    inherit (source) hash;
  };
  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 bin/node "$out/bin/node"
    install -Dm644 LICENSE "$out/share/licenses/node/LICENSE"
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/node" --version | grep -Fx 'v${version}'
    runHook postInstallCheck
  '';
  meta = {
    description = "Official Node runtime isolated to DeepSeek Harness native addons";
    homepage = "https://nodejs.org";
    license = lib.licenses.mit;
    platforms = builtins.attrNames sources;
  };
}
