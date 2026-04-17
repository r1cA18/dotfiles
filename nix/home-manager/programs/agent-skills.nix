{ inputs, ... }:
{
  programs.agent-skills = {
    enable = true;

    sources = {
      # 自作スキル (dotfiles/skills/)
      custom = {
        path = ../../../skills;
      };

      # Anthropic 公式スキル
      anthropic = {
        path = inputs.anthropic-skills;
        subdir = "skills";
      };

      # difit スキル
      difit = {
        path = inputs.difit-skills;
        subdir = "skills";
      };

    };

    skills = {
      # 自作スキルは全て有効化
      enableAll = [ "custom" ];

      # 公式スキルは個別に有効化
      enable = [
        "difit"
        "difit-review"
        "pdf"
        "xlsx"
        "frontend-design"
        # "skill-creator"
      ];
    };

    # Claude / Codex に同期
    targets = {
      claude = {
        dest = "\${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills";
        structure = "symlink-tree";
        enable = true;
        systems = [ ];
      };
      codex = {
        dest = "\${CODEX_HOME:-$HOME/.codex}/skills";
        structure = "symlink-tree";
        enable = true;
        systems = [ ];
      };
      opencode.enable = false;
    };
  };
}
