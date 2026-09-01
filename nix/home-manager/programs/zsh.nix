{
  hostname ? null,
  pkgs,
  lib,
  username,
  ...
}:
let
  inherit (pkgs.stdenv) isDarwin;
  linuxConfigName = if hostname == null then "${username}@linux" else "${username}@${hostname}";

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
  };

  nixCommonAliases = {
    nx = {
      cmd = "cd ~/dotfiles";
      desc = "Go to dotfiles flake root";
    };
    du = {
      cmd = "nix flake update --flake ~/dotfiles && update-github-apps && update-claude-code && update-antigravity";
      desc = "Update flake + GitHub apps + Claude Code + Antigravity";
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
      cmd = "nh home switch ~/dotfiles -c ${linuxConfigName}";
      desc = "Apply Home Manager config";
    };
    db = {
      cmd = "nh home build ~/dotfiles -c ${linuxConfigName}";
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
      cmd = "cd ~/Library/CloudStorage/GoogleDrive-*/My\\ Drive/";
      desc = "Go to Google Drive";
    };
    storage = {
      cmd = "cd ~/Library/CloudStorage/GoogleDrive-*/My\\ Drive/Storage/";
      desc = "Go to Storage";
    };
    vault = {
      cmd = "cd ~/vault/";
      desc = "Go to Vault";
    };
    kosen = {
      cmd = "cd ~/Develop/github.com/r1cA18/kosen/5y/spring_semester/";
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
      cmd = "clp run";
      desc = "Start Claude Code with account picker";
    };
    clg = {
      cmd = "clp gpt";
      desc = "Start GPT backend with account picker";
    };
    clw = {
      cmd = "ANTHROPIC_API_KEY=\${CLAUDE_CSTYLE_API_KEY} claude";
      desc = "Start Claude with work API key";
    };
    # session actions
    clc = {
      cmd = "clp run default --continue";
      desc = "Continue last Claude session";
    };
    clcd = {
      cmd = "clp run default --continue --dangerously-skip-permissions";
      desc = "Continue Claude session without prompts";
    };
    clr = {
      cmd = "clp run default --resume";
      desc = "Resume Claude session from picker";
    };
    clgc = {
      cmd = "clp gpt default --continue";
      desc = "Continue last GPT-backed Claude session";
    };
    clgr = {
      cmd = "clp gpt default --resume";
      desc = "Resume GPT-backed Claude session from picker";
    };
    cld = {
      cmd = "clp run default --dangerously-skip-permissions";
      desc = "Start Claude without prompts";
    };
    clgd = {
      cmd = "clp gpt default --dangerously-skip-permissions";
      desc = "Start GPT-backed Claude without prompts";
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
  # `cx` opens the account picker. Named model layers are loaded from the
  # selected CODEX_HOME as heavy.config.toml / spark.config.toml.
  codexAliases = {
    # base + profile variants
    cx = {
      cmd = "cxp run";
      desc = "Start Codex with account picker";
    };
    cxh = {
      cmd = "cxp run default --profile heavy";
      desc = "Start Codex with heavy profile (gpt-5.5 high)";
    };
    cxsp = {
      cmd = "cxp run default --profile spark";
      desc = "Start Codex with spark profile";
    };
    # session actions
    cxc = {
      cmd = "cxp run default resume --last";
      desc = "Continue last Codex session";
    };
    cxcd = {
      cmd = "cxp run default resume --last --dangerously-bypass-approvals-and-sandbox";
      desc = "Continue Codex without prompts";
    };
    cxr = {
      cmd = "cxp run default resume";
      desc = "Resume Codex session from picker";
    };
    cxf = {
      cmd = "cxp run default fork --last";
      desc = "Fork last Codex session";
    };
    cxd = {
      cmd = "cxp run default --dangerously-bypass-approvals-and-sandbox";
      desc = "Start Codex without prompts";
    };
    cxa = {
      cmd = "cxp run default --full-auto";
      desc = "Run Codex full-auto";
    };
    cxe = {
      cmd = "cxp run default exec";
      desc = "Run Codex non-interactively";
    };
    cxrev = {
      cmd = "cxp run default review";
      desc = "Run code review";
    };
    cxap = {
      cmd = "cxp run default apply";
      desc = "Apply latest Codex diff";
    };
  };

  # Executables do not become abbreviations. Keep them visible in h without
  # adding shell aliases that could shadow the real commands.
  canonicalCommands = {
    clp = {
      cmd = "clp <command>";
      desc = "Manage Claude account profiles";
    };
    cxp = {
      cmd = "cxp <command>";
      desc = "Manage Codex account profiles";
    };
    clgpt = {
      cmd = "clgpt [args]";
      desc = "Run Claude Code through the GPT proxy";
    };
    clproxy = {
      cmd = "clproxy <command>";
      desc = "Manage the Claude Code proxy";
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
    {
      title = "Agent Commands";
      defs = canonicalCommands;
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
  managedAbbrPairs = lib.concatMapStringsSep " " (name: "${lib.escapeShellArg name} 1") (
    builtins.attrNames abbrDefs
  );
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

            _agent_profile_completion() {
              local manager="$1"
              local -a commands profiles
              commands=(
                'list:List account profiles'
                'add:Add an account profile'
                'login:Sign in to an account profile'
                'status:Show authentication status'
                'path:Print the profile data directory'
                'run:Start with an account profile'
                'complete:Print completion candidates'
              )
              if [[ "$manager" == "clp" ]]; then
                commands+=( 'gpt:Start the GPT backend with an account profile' )
              fi

              if (( CURRENT == 2 )); then
                _describe 'command' commands
                return
              fi

              if (( CURRENT == 3 )) && [[ "$words[2]" == (run|gpt|login|status|path) ]]; then
                profiles=("''${(@f)$("$manager" complete 2>/dev/null)}")
                _describe 'account profile' profiles
                return
              fi

              _normal
            }

            _clp() { _agent_profile_completion clp; }
            _cxp() { _agent_profile_completion cxp; }
            compdef _clp clp
            compdef _cxp cxp

            [[ -f ~/.config/secrets/appstore.env ]] && source ~/.config/secrets/appstore.env
            [[ -f ~/.config/secrets/claude.env ]] && source ~/.config/secrets/claude.env

            _dotfiles_help() {
              local mode="$1"
              shift || true

              local query="$*"
              local content
              local runtime_content=""
              local raw_name name expansion
              local -A managed_abbrs
              managed_abbrs=( ${managedAbbrPairs} )

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

              while IFS= read -r raw_name; do
                name="''${(Q)raw_name}"
                [[ -n "''${managed_abbrs[$name]-}" ]] && continue
                expansion="$(abbr expand "$name" 2>/dev/null)" || continue
                runtime_content+="$name = $expansion"$'\n'
              done < <(abbr list-abbreviations 2>/dev/null)

              if [[ -n "$runtime_content" ]]; then
                content+=$'\n\n[Runtime abbreviations]\n'
                content+="''${runtime_content%$'\n'}"
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
