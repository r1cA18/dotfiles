{
  autoPatchelfHook,
  fetchurl,
  glibc,
  lib,
  makeWrapper,
  stdenv,
}:
let
  releases = {
    aarch64-darwin = {
      platform = "darwin-arm64";
      hash = "sha256-DJE1IaTF02q1xdZxaB9Lup0V8eAuH7r8WSQkqPN6Q5s=";
    };
    x86_64-linux = {
      platform = "linux-x64";
      hash = "sha256-TDRT7JSSt/YY6pMGyivJbb0Q/0vtqgRIaN5tC0UnrpY=";
    };
  };
  release = releases.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation rec {
  pname = "indexion";
  version = "0.18.0";

  src = fetchurl {
    url = "https://github.com/trkbt10/indexion/releases/download/v${version}/indexion-${release.platform}.tar.gz";
    inherit (release) hash;
  };

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ glibc ];
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 indexion "$out/libexec/indexion"
    mkdir -p "$out/bin" "$out/share/indexion"
    cp -R kgfs wiki "$out/share/indexion/"
    rm -f "$out/share/indexion/kgfs/.git"
    makeWrapper "$out/libexec/indexion" "$out/bin/indexion" \
      --set-default INDEXION_KGFS_DIR "$out/share/indexion/kgfs"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/indexion" --version
    "$out/bin/indexion" kgf list >/dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "Local codebase indexing, search, and knowledge graph CLI";
    homepage = "https://github.com/trkbt10/indexion";
    license = lib.licenses.asl20;
    mainProgram = "indexion";
    platforms = builtins.attrNames releases;
  };
}
