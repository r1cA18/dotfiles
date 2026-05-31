# GitHub release で配布される macOS GUI アプリ (.dmg / .zip) を
# Nix パッケージ化する汎用ヘルパー。callPackage で nixpkgs 依存を注入し、
# 返り値の関数にアプリ固有の引数 (owner/repo/asset/hash 等) を渡す。
{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
  unzip,
}:
{
  pname,
  version,
  owner,
  repo,
  asset,
  hash,
  tag ? "v${version}",
  format ? "dmg", # "dmg" | "zip"
  platforms ? [ "aarch64-darwin" ],
  description ? "",
  homepage ? "https://github.com/${owner}/${repo}",
  license ? lib.licenses.unfree,
}:
stdenvNoCC.mkDerivation (
  {
    inherit pname version;

    src = fetchurl {
      url = "https://github.com/${owner}/${repo}/releases/download/${tag}/${asset}";
      inherit hash;
    };

    sourceRoot = ".";

    # .dmg は undmg の setup-hook が src を自動展開する。.zip のみ明示展開。
    nativeBuildInputs = if format == "zip" then [ unzip ] else [ undmg ];

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/Applications"
      cp -r *.app "$out/Applications/"
      runHook postInstall
    '';

    meta = {
      inherit
        description
        homepage
        license
        platforms
        ;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  }
  # 空の unpackPhase 属性は stdenv のデフォルト展開を潰すため、
  # .zip のときだけ属性ごと付与する (optionalString ではなく optionalAttrs)。
  // lib.optionalAttrs (format == "zip") {
    unpackPhase = ''
      runHook preUnpack
      unzip -q "$src"
      runHook postUnpack
    '';
  }
)
