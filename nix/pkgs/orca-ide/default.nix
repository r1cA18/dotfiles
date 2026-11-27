{
  lib,
  appimageTools,
  buildFHSEnv,
  bubblewrap,
  fetchurl,
  runCommand,
  xvfb,
}:
let
  # A real copy, not a symlink: AppArmor matches the resolved executable path.
  # server/ansible/templates/orca-ide.apparmor.j2 grants userns to this path only.
  orcaBubblewrap = runCommand "orca-ide-bubblewrap" { } ''
    install -Dm755 ${bubblewrap}/bin/bwrap $out/bin/bwrap
  '';
  appimageTools' = appimageTools.override {
    buildFHSEnv = buildFHSEnv.override { bubblewrap = orcaBubblewrap; };
  };
in
appimageTools'.wrapType2 rec {
  pname = "orca-ide";
  version = "1.4.215";

  src = fetchurl {
    url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
    hash = "sha256-HogcGez9+008VwHD7mBNRkBIG0S1EAo5P2NEma+lpN0=";
  };

  # `orca serve` starts its own Xvfb when no DISPLAY is set.
  extraPkgs = _: [ xvfb ];

  meta = {
    description = "Orca IDE runtime for headless `orca-ide serve`";
    homepage = "https://github.com/stablyai/orca";
    license = lib.licenses.mit;
    mainProgram = "orca-ide";
    platforms = [ "x86_64-linux" ];
  };
}
