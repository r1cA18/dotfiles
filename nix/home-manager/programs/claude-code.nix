{
  config,
  lib,
  username,
  pkgs,
  ...
}:
let
  homeDir = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
  dotfilesDir = "${homeDir}/dotfiles";
  python3 = lib.getExe pkgs.python3;

  mkClaudeSymlink = relativePath: {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/${relativePath}";
    force = true;
  };
in
{
  programs.claude-code = {
    enable = true;
    # claude is self-installed at ~/.local/bin/claude (auto-updating).
    # The Nix-wrapped binary would be shadowed anyway, so don't install it.
    # mcpServers/lspServers/plugins must stay empty when package=null.
    package = null;

    # All settings.json content — Nix is the source of truth.
    # IMPORTANT: every key listed here is fully managed; on each `dr` the
    # live ~/.claude/settings.json is regenerated from this attrset, so any
    # in-app mutations (/model, /theme, /editorMode, plugin toggles via
    # /config, etc.) are reset to the values declared here. That's the
    # intended workflow: keep dotfiles diff clean, accept that runtime
    # changes are session-scoped unless promoted to this file.
    settings = {
      "$schema" = "https://json.schemastore.org/claude-code-settings.json";
      env = {
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
        CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1";
      };

      permissions = {
        allow = [
          "Bash(bun *)"
          "Bash(npx prettier *)"
          "Bash(npx eslint *)"
          "Bash(git status)"
          "Bash(git diff *)"
          "Bash(git log *)"
          "Bash(git commit *)"
          "Bash(git push)"
          "Bash(git push origin *)"
          "Bash(git push -u origin *)"
          "Bash(git fetch *)"
          "Bash(git pull *)"
          "Bash(git checkout *)"
          "Bash(git switch *)"
          "Bash(git branch *)"
          "Bash(git merge --ff-only *)"
          "Bash(git rebase *)"
          "Bash(ls *)"
        ];
        deny = [
          "Read(~/.ssh/**)"
          "Edit(~/.ssh/**)"
          "Write(~/.ssh/**)"
          "Read(~/.gnupg/**)"
          "Read(~/.aws/**)"
          "Read(~/.azure/**)"
          "Read(~/.kube/**)"
          "Read(~/.npmrc)"
          "Read(~/.git-credentials)"
          "Read(~/.config/gh/**)"
          "Edit(~/.bashrc)"
          "Edit(~/.zshrc)"
          "Bash(curl *)"
          "Bash(wget *)"
          "Bash(nc *)"
          "Bash(ssh *)"
          "Bash(git push --force*)"
          "Bash(git push -f*)"
          "Bash(git push * --force*)"
          "Bash(git push * -f*)"
          "Bash(git reset --hard*)"
          "Read(*.env)"
          "Read(.env.*)"
          "Edit(*.env)"
          "Edit(.env.*)"
          "Write(*.env)"
          "Write(.env.*)"
          "Edit(*.key)"
          "Write(*.key)"
          "Edit(*.pem)"
          "Write(*.pem)"
          "Edit(**/secrets/**)"
          "Write(**/secrets/**)"
          "Edit(**/credentials/**)"
          "Write(**/credentials/**)"
        ];
        defaultMode = "auto";
      };

      enableAllProjectMcpServers = false;

      hooks = {
        PreToolUse = [
          {
            matcher = "Edit|Write";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/emoji-guard.sh";
              }
            ];
          }
          {
            matcher = "Write";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/large-file-guard.sh";
              }
            ];
          }
          {
            matcher = "Bash";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/debug-print-guard.sh";
              }
            ];
          }
        ];
        PostToolUse = [
          {
            matcher = "Edit|Write";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/auto-format.sh";
              }
              {
                type = "command";
                command = "~/.claude/hooks/ai-slop-guard.sh";
              }
              {
                type = "command";
                command = "~/.claude/hooks/test-reminder.sh";
              }
            ];
          }
          {
            matcher = "*";
            hooks = [
              {
                type = "command";
                command = ''[ -n "$SUPERSET_HOME_DIR" ] && [ -x "$SUPERSET_HOME_DIR/hooks/notify.sh" ] && "$SUPERSET_HOME_DIR/hooks/notify.sh" || true'';
              }
            ];
          }
        ];
        Notification = [
          {
            matcher = "idle_prompt";
            hooks = [
              {
                type = "command";
                command = "afplay /System/Library/Sounds/Submarine.aiff 2>/dev/null || true";
              }
            ];
          }
          {
            matcher = "permission_prompt";
            hooks = [
              {
                type = "command";
                command = "afplay /System/Library/Sounds/Ping.aiff 2>/dev/null || true";
              }
            ];
          }
        ];
        Stop = [
          {
            hooks = [
              {
                type = "command";
                command = "afplay /System/Library/Sounds/Funk.aiff 2>/dev/null || true";
              }
            ];
          }
          {
            hooks = [
              {
                type = "command";
                command = ''[ -n "$SUPERSET_HOME_DIR" ] && [ -x "$SUPERSET_HOME_DIR/hooks/notify.sh" ] && "$SUPERSET_HOME_DIR/hooks/notify.sh" || true'';
              }
            ];
          }
        ];
        UserPromptSubmit = [
          {
            hooks = [
              {
                type = "command";
                command = ''[ -n "$SUPERSET_HOME_DIR" ] && [ -x "$SUPERSET_HOME_DIR/hooks/notify.sh" ] && "$SUPERSET_HOME_DIR/hooks/notify.sh" || true'';
              }
            ];
          }
        ];
        PostToolUseFailure = [
          {
            matcher = "*";
            hooks = [
              {
                type = "command";
                command = ''[ -n "$SUPERSET_HOME_DIR" ] && [ -x "$SUPERSET_HOME_DIR/hooks/notify.sh" ] && "$SUPERSET_HOME_DIR/hooks/notify.sh" || true'';
              }
            ];
          }
        ];
        PermissionRequest = [
          {
            matcher = "*";
            hooks = [
              {
                type = "command";
                command = ''[ -n "$SUPERSET_HOME_DIR" ] && [ -x "$SUPERSET_HOME_DIR/hooks/notify.sh" ] && "$SUPERSET_HOME_DIR/hooks/notify.sh" || true'';
              }
            ];
          }
        ];
      };

      enabledPlugins = {
        "document-skills@anthropic-agent-skills" = true;
        "swift-lsp@claude-plugins-official" = true;
        "typescript-lsp@claude-plugins-official" = true;
        "hookify@claude-plugins-official" = true;
        "context7@claude-plugins-official" = true;
        "pyright-lsp@claude-plugins-official" = true;
        "mgrep@Mixedbread-Grep" = true;
        "sharp-aircon@sharp-aircon-plugins" = true;
        "academic-research-skills@academic-research-skills" = true;
        "ralph-loop@claude-plugins-official" = true;
        "plugin-dev@claude-plugins-official" = true;
        "claude-md-management@claude-plugins-official" = true;
        "claude-code-setup@claude-plugins-official" = true;
        "commit-commands@claude-plugins-official" = true;
        "pr-review-toolkit@claude-plugins-official" = true;
        "feature-dev@claude-plugins-official" = true;
        "explanatory-output-style@claude-plugins-official" = true;
        "skill-creator@claude-plugins-official" = true;
        "playground@claude-plugins-official" = true;
        "frontend-design@claude-plugins-official" = true;
        "linear@claude-plugins-official" = true;
        "codex@openai-codex" = true;
      };

      extraKnownMarketplaces = {
        claude-plugins-official.source = {
          source = "git";
          url = "https://github.com/anthropics/claude-plugins-official.git";
        };
        sentry-plugin-marketplace.source = {
          source = "git";
          url = "https://github.com/getsentry/sentry-for-ai.git";
        };
        openai-codex.source = {
          source = "github";
          repo = "openai/codex-plugin-cc";
        };
        academic-research-skills.source = {
          source = "github";
          repo = "Imbad0202/academic-research-skills";
        };
      };

      language = "日本語, 敬語非使用";

      sandbox.filesystem.denyRead = [
        "./.env"
        "./.env.*"
      ];

      effortLevel = "high";
      skipDangerousModePermissionPrompt = true;
      skipAutoPermissionPrompt = true;
      remoteControlAtStartup = false;
      theme = "light";
      editorMode = "vim";
    };
  };

  # CLAUDE.md + editable directories — kept as out-of-store symlinks so
  # edits to ~/dotfiles/{shared,claude}/* take effect immediately without
  # requiring a `dr` (programs.claude-code.context would copy to nix store).
  home.file = {
    ".claude/CLAUDE.md" = mkClaudeSymlink "agents/INSTRUCTIONS.md";
    ".claude/mcp-servers.json" = mkClaudeSymlink "claude/mcp-servers.json";
    ".claude/rules" = mkClaudeSymlink "claude/rules";
    ".claude/hooks" = mkClaudeSymlink "claude/hooks";
    ".claude/commands" = mkClaudeSymlink "claude/commands";
    ".claude/agents" = mkClaudeSymlink "claude/agents";
  };

  # settings.json is a Nix-managed symlink, but Claude Code occasionally rewrites
  # it as a regular file (plugin installs, in-app /config edits). The next `dr`
  # then tries to back it up to settings.json.hm-backup and fails if a previous
  # backup already exists. Since Nix is the source of truth here, the backup has
  # no value — drop it before checkLinkTargets runs.
  home.activation.cleanClaudeSettingsBackup = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    rm -f "$HOME/.claude/settings.json.hm-backup"
  '';

  # MCP servers cannot use programs.claude-code.mcpServers (requires package!=null
  # and our claude is self-installed). Keep the python merge script that syncs
  # claude/mcp-servers.json into ~/.claude.json on every dr.
  home.activation.syncClaudeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "Syncing Claude MCP servers..."
    ${python3} \
      "${dotfilesDir}/claude/scripts/sync-mcp-servers.py" \
      "$HOME/.claude.json" \
      "${dotfilesDir}/claude/mcp-servers.json" || true
  '';
}
