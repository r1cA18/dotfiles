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
  sharedAgentInstructions = import ../../lib/agent-instructions.nix { inherit lib pkgs; };
  notificationCommand =
    sound:
    if pkgs.stdenv.isDarwin then
      "afplay /System/Library/Sounds/${sound}.aiff 2>/dev/null || true"
    else
      "canberra-gtk-play --id=message 2>/dev/null || true";

  # Claude Code (native installer) の追従チャネル。"latest" で du のたびに
  # 最新へ追従、版番号 (例 "2.1.150") でその版に固定/ロールバック。
  claudeChannel = "latest";

  mkClaudeSymlink = relativePath: {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/${relativePath}";
    force = true;
  };

  # Individual file symlinks for .claude/agents/. All agents (including the
  # repo-owned sc-*.md personas) live in claude/agents/ and are deployed here.
  # readDir uses the flake-relative path (pure-eval safe); symlinks point to
  # the mutable dotfilesDir so edits take effect without rebuild.
  agentFiles = lib.mapAttrs' (
    name: _: lib.nameValuePair ".claude/agents/${name}" (mkClaudeSymlink "claude/agents/${name}")
  ) (builtins.readDir ../../../claude/agents);
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
        # bg 自動更新を切り、更新経路を du (update-claude-code) に一元化する。
        DISABLE_AUTOUPDATER = "1";
      };

      permissions = {
        allow = [
          "Bash(bun install*)"
          "Bash(bun run *)"
          "Bash(bun test*)"
          "Bash(bun build *)"
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
              {
                # vault 20_Knowledge の index カバレッジ検査 (agents/hooks/ は
                # Codex と共有。Codex 側は codex/hooks.json の Stop hook で同じ
                # スクリプトを --all モードで呼ぶ)
                type = "command";
                command = "${lib.getExe pkgs.bun} ~/dotfiles/agents/hooks/check-knowledge-index.ts";
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
                command = notificationCommand "Submarine";
              }
            ];
          }
          {
            matcher = "permission_prompt";
            hooks = [
              {
                type = "command";
                command = notificationCommand "Ping";
              }
            ];
          }
        ];
        Stop = [
          {
            hooks = [
              {
                type = "command";
                command = notificationCommand "Funk";
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
        gsap-skills.source = {
          source = "github";
          repo = "greensock/gsap-skills";
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
      remoteControlAtStartup = true;
      theme = "light";
      editorMode = "vim";
      model = "claude-opus-4-6";
    };
  };

  # Shared instructions are generated from agents/INSTRUCTIONS.md and
  # agents/rules/*.md. Claude-specific assets remain editable symlinks.
  home = {
    file = {
      ".claude/CLAUDE.md".source = sharedAgentInstructions;
      ".claude/mcp-servers.json" = mkClaudeSymlink "claude/mcp-servers.json";
      ".claude/rules" = mkClaudeSymlink "claude/rules";
      ".claude/hooks" = mkClaudeSymlink "claude/hooks";
      ".claude/commands" = mkClaudeSymlink "claude/commands";
    }
    // agentFiles;

    activation = {
      # Older generations managed .claude/agents as one directory symlink. If its
      # Nix store target has been garbage-collected, linkGeneration cannot replace
      # the broken symlink with the directory required by per-agent file links.
      cleanBrokenClaudeAgentsSymlink = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        if [ -L "$HOME/.claude/agents" ] && [ ! -e "$HOME/.claude/agents" ]; then
          rm -f "$HOME/.claude/agents"
        fi
      '';

      # settings.json is a Nix-managed symlink, but Claude Code occasionally rewrites
      # it as a regular file (plugin installs, in-app /config edits). The next `dr`
      # then tries to back it up to settings.json.hm-backup and fails if a previous
      # backup already exists. Since Nix is the source of truth here, the backup has
      # no value — drop it before checkLinkTargets runs.
      cleanClaudeSettingsBackup = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        rm -f "$HOME/.claude/settings.json.hm-backup"
      '';

      # MCP servers cannot use programs.claude-code.mcpServers (requires package!=null
      # and our claude is self-installed). Keep the python merge script that syncs
      # claude/mcp-servers.json into ~/.claude.json on every dr.
      syncClaudeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        echo "Syncing Claude MCP servers..."
        ${python3} \
          "${dotfilesDir}/claude/scripts/sync-mcp-servers.py" \
          "$HOME/.claude.json" \
          "${dotfilesDir}/claude/mcp-servers.json" || true
      '';

      # Claude Code native 版の導入/固定。更新 (latest 追従) は du の
      # update-claude-code が担うので、ここは初回導入と固定版の適用のみ。
      # claudeChannel を managed-channel に書き出し、du スクリプトへ状態を渡す。
      setupClaudeCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        export PATH="${pkgs.curl}/bin:$PATH"
        channel="${claudeChannel}"
        bin="$HOME/.local/bin/claude"
        mkdir -p "$HOME/.claude"
        printf '%s\n' "$channel" > "$HOME/.claude/managed-channel"

        if [ ! -x "$bin" ]; then
          if [ "$channel" = "latest" ]; then
            ${pkgs.curl}/bin/curl -fsSL https://claude.ai/install.sh | bash || true
          else
            ${pkgs.curl}/bin/curl -fsSL https://claude.ai/install.sh | bash -s "$channel" || true
          fi
        elif [ "$channel" != "latest" ] && ! "$bin" --version 2>/dev/null | grep -q "$channel"; then
          ${pkgs.curl}/bin/curl -fsSL https://claude.ai/install.sh | bash -s "$channel" || true
        fi

        if command -v npm >/dev/null 2>&1; then
          ${pkgs.nodejs}/bin/npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || true
        fi
      '';
    };
  };
}
