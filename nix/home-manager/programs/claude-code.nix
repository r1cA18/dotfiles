{
  config,
  lib,
  username,
  pkgs,
  ...
}:
let
  homeDir = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/${username}" else "/home/${username}";
  dotfilesDir = "${homeDir}/dotfiles";
  sharedAgentInstructions = import ../../lib/agent-instructions.nix { inherit lib pkgs; };
  notificationCommand =
    sound:
    if pkgs.stdenv.hostPlatform.isDarwin then
      "afplay /System/Library/Sounds/${sound}.aiff 2>/dev/null || true"
    else
      "canberra-gtk-play --id=message 2>/dev/null || true";

  # Claude Code (native installer) の追従チャネル。"latest" で dot update のたびに
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

  claudeStatusline = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      pkgs.jq
    ];
    text = builtins.readFile ../../../claude/scripts/statusline.sh;
  };
  merge = import ../../lib/merge-managed.nix { inherit pkgs lib; };

  # settings.json keys Nix manages. Claude Code rewrites the file (plugin
  # installs, /config, /model), so it is a writable file: each activation
  # merges these keys into it, and keys it does not manage (plugins enabled
  # inside Claude Code, per-machine choices) stay. A key listed here is reset
  # to this value on every activation, as before. Plugins and their
  # marketplaces come from the capability catalog (r1hn on macOS,
  # capabilities.nix elsewhere); the marketplaces below only declare sources.
  claudeSettings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    env = {
      CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
      CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1";
      # Claude Mods (function hooks) 実験機能を有効化
      CLAUDE_CODE_ENABLE_FUNCTION_HOOKS = "1";
      # bg 自動更新を切り、更新経路を dot update (claude-code 段階) に一元化する。
      DISABLE_AUTOUPDATER = "1";
    };

    statusLine = {
      type = "command";
      command = lib.getExe claudeStatusline;
      padding = 0;
    };

    permissions = {
      allow = [
        "Bash(ssh *)"
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
        "Bash(git push --force*)"
        "Bash(git push -f*)"
        "Bash(git push * --force*)"
        "Bash(git push * -f*)"
        "Bash(git reset --hard*)"
        "Read(*.env)"
        "Read(.env.*)"
        "Edit(*.env)"
        "Edit(.env.*)"
        "Edit(*.key)"
        "Edit(*.pem)"
        "Edit(**/secrets/**)"
        "Edit(**/credentials/**)"
      ];
      defaultMode = "auto";
    };

    enableAllProjectMcpServers = false;

    hooks = {
      SessionStart = [
        {
          hooks = [
            {
              # Catalog entries that match the project, once per project
              # (agents/hooks/ is shared; Codex runs it from codex/hooks.json).
              type = "command";
              command = ''${lib.getExe pkgs.bun} "${dotfilesDir}/agents/hooks/capability-suggest.ts"'';
              timeout = 5;
            }
          ];
        }
      ];
      PreToolUse = [
        {
          matcher = "Edit|Write";
          hooks = [
            {
              type = "command";
              command = ''"${dotfilesDir}/claude/hooks/emoji-guard.sh"'';
              timeout = 5;
            }
          ];
        }
        {
          matcher = "Write";
          hooks = [
            {
              type = "command";
              command = ''"${dotfilesDir}/claude/hooks/large-file-guard.sh"'';
              timeout = 5;
            }
          ];
        }
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = ''PATH="${
                lib.makeBinPath [
                  pkgs.python3
                  pkgs.git
                ]
              }:$PATH" "${dotfilesDir}/claude/hooks/debug-print-guard.sh"'';
              timeout = 5;
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
              command = ''"${dotfilesDir}/claude/hooks/ai-slop-guard.sh"'';
              timeout = 5;
            }
            {
              # vault 20_Knowledge の index カバレッジ検査 (agents/hooks/ は
              # Codex と共有。Codex 側は codex/hooks.json の Stop hook で同じ
              # スクリプトを --stop モードで呼ぶ)
              type = "command";
              command = ''${lib.getExe pkgs.bun} "${dotfilesDir}/agents/hooks/check-knowledge-index.ts"'';
              timeout = 5;
            }
            {
              # 編集したrepoの scripts/check fast を呼び、失敗を知らせるだけ
              # (block しない)。Codex 側は codex/hooks.json の PostToolUse
              type = "command";
              command = ''PATH="${lib.makeBinPath [ pkgs.git ]}:$PATH" ${lib.getExe pkgs.bun} "${dotfilesDir}/agents/hooks/run-repo-check.ts"'';
              timeout = 15;
            }
          ];
        }
        {
          matcher = "*";
          hooks = [
            {
              type = "command";
              command = ''[ -n "$SUPERSET_HOME_DIR" ] && [ -x "$SUPERSET_HOME_DIR/hooks/notify.sh" ] && "$SUPERSET_HOME_DIR/hooks/notify.sh" || true'';
              timeout = 5;
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
              timeout = 5;
            }
          ];
        }
        {
          matcher = "permission_prompt";
          hooks = [
            {
              type = "command";
              command = notificationCommand "Ping";
              timeout = 5;
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
              timeout = 5;
            }
          ];
        }
        {
          hooks = [
            {
              type = "command";
              command = ''[ -n "$SUPERSET_HOME_DIR" ] && [ -x "$SUPERSET_HOME_DIR/hooks/notify.sh" ] && "$SUPERSET_HOME_DIR/hooks/notify.sh" || true'';
              timeout = 5;
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
              timeout = 5;
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
              timeout = 5;
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
              timeout = 5;
            }
          ];
        }
      ];
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
  };

  # Marketplaces offered without enabling a plugin from them.
  claudeMarketplaces = {
    claude-plugins-official.source = {
      source = "git";
      url = "https://github.com/anthropics/claude-plugins-official.git";
    };
    sentry-plugin-marketplace.source = {
      source = "git";
      url = "https://github.com/getsentry/sentry-for-ai.git";
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
in
{
  programs.claude-code = {
    enable = true;
    # claude is self-installed at ~/.local/bin/claude (auto-updating).
    # The Nix-wrapped binary would be shadowed anyway, so don't install it.
    # mcpServers/lspServers/plugins must stay empty when package=null.
    package = null;
  };

  # Shared instructions are generated from agents/INSTRUCTIONS.md and
  # agents/rules/*.md. Claude-specific assets remain editable symlinks.
  home = {
    packages = [
      claudeStatusline
    ];

    file = {
      ".claude/CLAUDE.md".source = sharedAgentInstructions;
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

      # settings.json used to be a link into the store; Claude Code rewrote
      # it on plugin installs and the next activation failed on the backup.
      # It is now a writable file with the managed keys merged in.
      cleanClaudeSettingsBackup = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        rm -f "$HOME/.claude/settings.json.hm-backup"
      '';
      claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] (merge {
        format = "json";
        target = "$HOME/.claude/settings.json";
        name = "claude-settings";
        fragment = {
          set = claudeSettings;
          entries.extraKnownMarketplaces = claudeMarketplaces;
        };
      });

      # Claude Code native 版の導入/固定。更新 (latest 追従) は dot update の
      # claude-code 段階が担うので、ここは初回導入と固定版の適用のみ。
      # claudeChannel を managed-channel に書き出し、dot update の更新処理へ状態を渡す。
      setupClaudeCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        export PATH="${
          lib.makeBinPath (
            with pkgs;
            [
              curl
              gnutar
              gzip
              coreutils
              bash
            ]
          )
        }:$PATH:/usr/bin:/bin"
        channel="${claudeChannel}"
        bin="$HOME/.local/bin/claude"
        log="$HOME/.local/state/claude-code/install.log"
        mkdir -p "$HOME/.claude" "$(dirname "$log")"
        printf '%s\n' "$channel" > "$HOME/.claude/managed-channel"

        install_claude() {
          if [ "$channel" = "latest" ]; then
            ${pkgs.curl}/bin/curl -fsSL https://claude.ai/install.sh | bash
          else
            ${pkgs.curl}/bin/curl -fsSL https://claude.ai/install.sh | bash -s "$channel"
          fi
        }

        if [ ! -x "$bin" ]; then
          install_claude >>"$log" 2>&1 || echo "[claude-code] install failed, see $log" >&2
        elif [ "$channel" != "latest" ] && ! "$bin" --version 2>/dev/null | grep -q "$channel"; then
          install_claude >>"$log" 2>&1 || echo "[claude-code] install failed, see $log" >&2
        fi
      '';
    };
  };
}
