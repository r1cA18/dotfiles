{inputs, ...}: {
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
    };

    skills = {
      # 自作スキルは全て有効化
      enableAll = ["custom"];

      # 公式スキルは個別に有効化 (必要に応じて追加)
      enable = [
        # "pdf"
        # "xlsx"
        # "frontend-design"
        # "skill-creator"
      ];
    };

    # Claude Code のみに同期
    targets = {
      claude = {
        dest = "\${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills";
        structure = "symlink-tree";
        enable = true;
        systems = [];
      };
      codex.enable = false;
      opencode.enable = false;
    };
  };
}
