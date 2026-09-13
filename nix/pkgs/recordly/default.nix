# version / hash は各 1 行を維持すること (update-github-apps の sed が依存)。
{
  lib,
  mkGithubReleaseApp,
}:
mkGithubReleaseApp {
  pname = "recordly";
  version = "1.4.0";
  owner = "webadderallorg";
  repo = "Recordly";
  # Apple Silicon ビルドのみ (Intel が必要になったら x64 dmg で分岐する)
  asset = "Recordly-arm64.dmg";
  hash = "sha256-Ug7h1VcPI0LhJjBu2oS5XkQshEtvDoTG6BwghEW+jMQ=";
  format = "dmg";
  description = "Screen recording and editing desktop app for demo videos";
  platforms = [ "aarch64-darwin" ];
  license = lib.licenses.unfree;
}
