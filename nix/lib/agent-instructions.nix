{
  lib,
  pkgs,
  extraFiles ? [ ],
}:

let
  instructionFiles = [
    ../../agents/INSTRUCTIONS.md
    ../../agents/rules/engineering.md
    ../../agents/rules/orchestration.md
    ../../agents/rules/style.md
    ../../agents/rules/environment.md
    ../../agents/rules/tool-preferences.md
  ]
  ++ extraFiles;
in
pkgs.writeText "shared-agent-instructions.md" (
  lib.concatMapStringsSep "\n\n" builtins.readFile instructionFiles
)
