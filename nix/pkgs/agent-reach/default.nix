{
  python3Packages,
  fetchFromGitHub,
  lib,
  makeWrapper,
  gh,
  nodejs,
}:
python3Packages.buildPythonApplication rec {
  pname = "agent-reach";
  version = "1.5.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "Panniantong";
    repo = "Agent-Reach";
    rev = "v${version}";
    hash = "sha256-rCEtsGDa+CzEGavRPKDtjy1SNrUGdrgtq+iWkOaQbIQ=";
  };

  build-system = [ python3Packages.hatchling ];

  dependencies = with python3Packages; [
    requests
    feedparser
    python-dotenv
    loguru
    pyyaml
    rich
    yt-dlp
  ];

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram "$out/bin/agent-reach" \
      --prefix PATH : "${lib.makeBinPath [ gh nodejs ]}"
  '';

  doCheck = false;

  meta = with lib; {
    description = "Internet capability router for AI agents";
    homepage = "https://github.com/Panniantong/Agent-Reach";
    license = licenses.mit;
    mainProgram = "agent-reach";
    platforms = platforms.unix;
  };
}
