{
  hostname ? null,
  pkgs,
  lib,
  username,
  ...
}:
let
  inherit (pkgs.stdenv) isDarwin;

  generalAliases = {
    ll = {
      cmd = "eza -la --group-directories-first --icons=auto";
      desc = "List files with eza";
    };
    nv = {
      cmd = "nvim";
      desc = "Open Neovim";
    };
    dot = {
      cmd = "cd ~/dotfiles";
      desc = "Go to dotfiles";
    };
    gacm = {
      cmd = "git add -A && git commit -m";
      desc = "Add all + commit";
    };
    homelab-win = {
      cmd = "ssh -t homelab 'sudo efibootmgr -n 0000 && sudo reboot'";
      desc = "Reboot homelab into Windows via UEFI BootNext (Boot0000)";
    };
  };

  nixCommonAliases = {
    nx = {
      cmd = "cd ~/dotfiles";
      desc = "Go to dotfiles flake root";
    };
    du = {
      cmd = "nix flake update --flake ~/dotfiles && update-github-apps && update-claude-code";
      desc = "Update flake + GitHub apps + Claude Code";
    };
    ds = {
      cmd = "nix search nixpkgs";
      desc = "Search nixpkgs";
    };
    dg = {
      cmd = "nh clean all --keep-since 14d --keep 5";
      desc = "Clean old generations and store paths";
    };
    nd = {
      cmd = "nix develop";
      desc = "Enter nix develop shell";
    };
  };

  nixDarwinAliases = {
    dr = {
      cmd = "nh darwin switch ~/dotfiles -H ${hostname}";
      desc = "Apply Darwin config";
    };
    db = {
      cmd = "nh darwin build ~/dotfiles -H ${hostname}";
      desc = "Build Darwin config";
    };
    dp = {
      cmd = "darwin-rebuild switch --rollback";
      desc = "Rollback Darwin config";
    };
  };

  nixLinuxAliases = {
    dr = {
      cmd = "nh home switch ~/dotfiles -c ${username}@linux";
      desc = "Apply Home Manager config";
    };
    db = {
      cmd = "nh home build ~/dotfiles -c ${username}@linux";
      desc = "Build Home Manager config";
    };
    dp = {
      cmd = "home-manager generations";
      desc = "List Home Manager generations";
    };
  };

  dirDarwinAliases = {
    dev = {
      cmd = "cd ~/Develop/";
      desc = "Go to Develop (use devg for picker)";
    };
    drive = {
      cmd = "cd ~/Library/CloudStorage/GoogleDrive-ryo20061018@gmail.com/My\\ Drive/";
      desc = "Go to Google Drive";
    };
    storage = {
      cmd = "cd ~/Library/CloudStorage/GoogleDrive-ryo20061018@gmail.com/My\\ Drive/Storage/";
      desc = "Go to Storage";
    };
    vault = {
      cmd = "cd ~/vault/";
      desc = "Go to Vault";
    };
    kosen = {
      cmd = "cd ~/vault/31_Areas/Kosen/5y/spring_semester/";
      desc = "Go to Kosen";
    };
    downloads = {
      cmd = "cd ~/Downloads/";
      desc = "Go to Downloads";
    };
  };

  dirLinuxAliases = {
    dev = {
      cmd = "cd ~/Develop/";
      desc = "Go to Develop (use devg for picker)";
    };
    vault = {
      cmd = "cd /home/${username}/vault/";
      desc = "Go to Vault";
    };
    downloads = {
      cmd = "cd ~/Downloads/";
      desc = "Go to Downloads";
    };
  };

  # Claude Code abbreviations.
  # All entries are zsh-abbr expansions: type the alias + space and the full
  # command appears inline before Enter. No custom functions, no -s/-w flag
  # interception — each variation gets its own abbr so the resolved command is
  # always visible.
  claudeAliases = {
    # base + account variants
    cl = {
      cmd = "claude";
      desc = "Start Claude Code";
    };
    clsub = {
      cmd = "CLAUDE_CONFIG_DIR=$HOME/.claude-sub claude";
      desc = "Start Claude with sub account";
    };
    clw = {
      cmd = "ANTHROPIC_API_KEY=\${CLAUDE_CSTYLE_API_KEY} claude";
      desc = "Start Claude with work API key";
    };
    # session actions
    clc = {
      cmd = "claude --continue";
      desc = "Continue last Claude session";
    };
    clcd = {
      cmd = "claude --continue --dangerously-skip-permissions";
      desc = "Continue Claude session without prompts";
    };
    clr = {
      cmd = "claude --resume";
      desc = "Resume Claude session from picker";
    };
    cld = {
      cmd = "claude --dangerously-skip-permissions";
      desc = "Start Claude without prompts";
    };
    clu = {
      cmd = "claude update";
      desc = "Check Claude updates";
    };
    cls = {
      cmd = "bunx ccusage";
      desc = "Show Claude usage (ccusage)";
    };
  };

  # Codex abbreviations.
  # `cx` uses the top-level `model` / `model_reasoning_effort` from
  # ~/.codex/config.toml (gpt-5.5 medium). `--profile heavy` / `--profile spark`
  # override per-invocation; `cxs` switches to the sub-account.
  codexAliases = {
    # base + profile variants
    cx = {
      cmd = "codex";
      desc = "Start Codex (default model)";
    };
    cxh = {
      cmd = "codex --profile heavy";
      desc = "Start Codex with heavy profile (gpt-5.5 high)";
    };
    cxsp = {
      cmd = "codex --profile spark";
      desc = "Start Codex with spark profile";
    };
    # account variants
    cxs = {
      cmd = "CODEX_HOME=$HOME/.codex-sub codex";
      desc = "Start Codex with sub account";
    };
    cxsh = {
      cmd = "CODEX_HOME=$HOME/.codex-sub codex --profile heavy";
      desc = "Start Codex with sub account + heavy profile";
    };
    # session actions
    cxc = {
      cmd = "codex resume --last";
      desc = "Continue last Codex session";
    };
    cxcd = {
      cmd = "codex resume --last --dangerously-bypass-approvals-and-sandbox";
      desc = "Continue Codex without prompts";
    };
    cxr = {
      cmd = "codex resume";
      desc = "Resume Codex session from picker";
    };
    cxf = {
      cmd = "codex fork --last";
      desc = "Fork last Codex session";
    };
    cxd = {
      cmd = "codex --dangerously-bypass-approvals-and-sandbox";
      desc = "Start Codex without prompts";
    };
    cxa = {
      cmd = "codex --full-auto";
      desc = "Run Codex full-auto";
    };
    cxe = {
      cmd = "codex exec";
      desc = "Run Codex non-interactively";
    };
    cxrev = {
      cmd = "codex review";
      desc = "Run code review";
    };
    cxap = {
      cmd = "codex apply";
      desc = "Apply latest Codex diff";
    };
  };

  aliasOnlyDefs = {
    ".." = {
      cmd = "cd ..";
      desc = "Go up one directory";
    };
    "..." = {
      cmd = "cd ../..";
      desc = "Go up two directories";
    };
  };

  helpSections = [
    {
      title = "General";
      defs = generalAliases // aliasOnlyDefs;
    }
    {
      title = "Nix";
      defs = nixCommonAliases // (if isDarwin then nixDarwinAliases else nixLinuxAliases);
    }
    {
      title = "Directory";
      defs = if isDarwin then dirDarwinAliases else dirLinuxAliases;
    }
    {
      title = "Claude Code";
      defs = claudeAliases;
    }
    {
      title = "Codex";
      defs = codexAliases;
    }
  ];

  abbrDefs =
    generalAliases
    // nixCommonAliases
    // (if isDarwin then nixDarwinAliases else nixLinuxAliases)
    // (if isDarwin then dirDarwinAliases else dirLinuxAliases)
    // claudeAliases
    // codexAliases;

  managedShellAliases = aliasOnlyDefs // abbrDefs;

  mkAbbrInit =
    defs:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "abbr -S -qq ${name}=${lib.escapeShellArg value.cmd}") defs
    );

  mkHelpLine =
    mode: name: value:
    if mode == "commands" then "${name} = ${value.cmd}" else "${name} - ${value.desc}";

  mkHelpSection =
    mode: section:
    let
      lines = lib.mapAttrsToList (name: value: mkHelpLine mode name value) section.defs;
    in
    "[${section.title}]\n" + lib.concatStringsSep "\n" lines;

  helpTextDescriptions = lib.concatStringsSep "\n\n" (
    map (mkHelpSection "descriptions") helpSections
  );
  helpTextCommands = lib.concatStringsSep "\n\n" (map (mkHelpSection "commands") helpSections);
in
{
  home.file.".p10k.zsh".source = ./p10k.zsh;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "docker"
        "sudo"
        "extract"
      ];
    };

    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
      {
        name = "zsh-abbr";
        src = pkgs.zsh-abbr;
        file = "share/zsh/zsh-abbr/zsh-abbr.plugin.zsh";
      }
    ];

    shellAliases = lib.mapAttrs (_: value: value.cmd) managedShellAliases;

    initContent = ''
            [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

            ${mkAbbrInit abbrDefs}

            [[ -f ~/.config/secrets/appstore.env ]] && source ~/.config/secrets/appstore.env
            [[ -f ~/.config/secrets/claude.env ]] && source ~/.config/secrets/claude.env

            _dotfiles_help() {
              local mode="$1"
              shift || true

              local query="$*"
              local content

              if [[ "$mode" == "commands" ]]; then
                content=$(cat <<'EOF'
      ${helpTextCommands}
      EOF
      )
              else
                content=$(cat <<'EOF'
      ${helpTextDescriptions}
      EOF
      )
              fi

              if [[ -n "$query" ]]; then
                print -r -- "$content" | rg -i --color=never -- "$query"
              else
                print -r -- "$content"
              fi
            }

            h() {
              _dotfiles_help descriptions "$@"
            }

            hv() {
              _dotfiles_help commands "$@"
            }

            devg() {
              local ghq_root repo

              ghq_root="$(ghq root 2>/dev/null || printf '%s\n' "$HOME/Develop")"
              repo="$(
                (
                  ghq list -p
                  find "$ghq_root/local" -maxdepth 1 -mindepth 1 -type d
                ) 2>/dev/null | awk '!seen[$0]++' | fzf --reverse --height 40%
              )"

              [[ -n "$repo" ]] && cd "$repo"
            }

    '';
  };
}
