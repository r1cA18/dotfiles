{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.harnessRuntime;
  sharedInstructions = import ../../lib/agent-instructions.nix { inherit lib pkgs; };
  skillsDirectory = "${config.home.homeDirectory}/.dsh/skills";
  hasSkillsModule = options.programs ? agent-skills;
  scripts = pkgs.runCommand "harness-runtime-scripts" { } ''
    mkdir -p "$out"
    cp ${../../../agents/scripts/model-connection.ts} "$out/model-connection.ts"
    cp ${../../../agents/scripts/harness-profile.ts} "$out/harness-profile.ts"
    cp ${../../../agents/scripts/harness-runtime.ts} "$out/harness-runtime.ts"
    cp ${../../../agents/scripts/runtime-process.ts} "$out/runtime-process.ts"
    cp ${../../../agents/scripts/harness-improvement-runtime.ts} "$out/harness-improvement-runtime.ts"
  '';
  command =
    name: script:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.bun ];
      text =
        lib.optionalString (cfg.dsh.enable && name == "harness-runtime") ''
          export HARNESS_SHARED_INSTRUCTIONS=${lib.escapeShellArg (toString sharedInstructions)}
          ${lib.optionalString cfg.dsh.shareSkills "export HARNESS_SHARED_SKILLS=${lib.escapeShellArg skillsDirectory}"}
        ''
        + ''
          exec bun ${scripts}/${script} "$@"
        '';
    };
in
{
  options.dotfiles.harnessRuntime = {
    enable = lib.mkEnableOption "opt-in harness connection planning and explicit runtime launch";
    dsh = {
      enable = lib.mkEnableOption "pinned DeepSeek Harness and shared instructions";
      shareSkills = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Deploy the same selected Agent Skills through agent-skills-nix to DeepSeek Harness.";
      };
    };
  };
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages = [
          (command "harness-connection" "model-connection.ts")
          (command "harness-profile" "harness-profile.ts")
          (command "harness-runtime" "harness-runtime.ts")
          (command "harness-improvement-runtime" "harness-improvement-runtime.ts")
        ];
      }
      (lib.mkIf cfg.dsh.enable (
        {
          assertions = [
            {
              assertion = !cfg.dsh.shareSkills || hasSkillsModule;
              message = "DeepSeek Harness skill sharing requires the agent-skills-nix Home Manager module; otherwise set dsh.shareSkills = false.";
            }
          ];
          home.packages = [ (pkgs.callPackage ../../pkgs/deepseek-harness { }) ];
          home.file.".dsh/AGENTS.md".source = sharedInstructions;
        }
        // lib.optionalAttrs hasSkillsModule {
          programs.agent-skills.targets.dsh = {
            enable = cfg.dsh.shareSkills;
            dest = skillsDirectory;
            structure = "symlink-tree";
            systems = [ ];
          };
        }
      ))
    ]
  );
}
