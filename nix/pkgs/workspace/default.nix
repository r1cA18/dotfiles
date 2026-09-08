{
  bun,
  ghq,
  git,
  indexion,
  ripgrep,
  writeShellApplication,
}:
writeShellApplication {
  name = "workspace";
  runtimeInputs = [
    bun
    ghq
    git
    indexion
    ripgrep
  ];
  text = ''
    export WORKSPACE_TEMPLATE_DIR=${../../../templates/workspace}
    export WORKSPACE_INDEXION_NIX=${../indexion/default.nix}
    exec bun ${../../../agents/scripts/workspace.ts} "$@"
  '';
}
