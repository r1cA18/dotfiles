# version / hash は各 1 行を維持すること (update-github-apps の sed が依存)。
{
  lib,
  mkGithubReleaseApp,
}:
mkGithubReleaseApp {
  pname = "recordly";
  version = "1.3.3";
  owner = "webadderallorg";
  repo = "Recordly";
  # Apple Silicon ビルドのみ (Intel が必要になったら x64 dmg で分岐する)
  asset = "Recordly-arm64.dmg";
  hash = "sha256-f6j0EW6HDUD9eLs20q0grzZMlFAjt7XsPnK1aLa73uU=";
  format = "dmg";
  description = "Screen recording and editing desktop app for demo videos";
  platforms = [ "aarch64-darwin" ];
  license = lib.licenses.unfree;
}
