{ lib, pkgs }:

let
  instructionFiles = [
    ../../agents/INSTRUCTIONS.md
    ../../agents/rules/engineering.md
    ../../agents/rules/style.md
    ../../agents/rules/environment.md
  ];
in
pkgs.writeText "shared-agent-instructions.md" (
  lib.concatMapStringsSep "\n\n" builtins.readFile instructionFiles
)
