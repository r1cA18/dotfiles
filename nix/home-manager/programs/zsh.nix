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
  };

  nixCommonAliases = {
    nx = {
      cmd = "cd ~/dotfiles";
      desc = "Go to dotfiles flake root";
    };
    du = {
      cmd = "nix flake update --flake ~/dotfiles";
      desc = "Update flake";
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

  claudeAliases = {
    clc = {
      cmd = "cl --continue";
      desc = "Continue last Claude session";
    };
    clcd = {
      cmd = "cl --continue --dangerously-skip-permissions";
      desc = "Continue Claude session without prompts";
    };
    clr = {
      cmd = "cl --resume";
      desc = "Resume Claude session from picker";
    };
    cld = {
      cmd = "cl --dangerously-skip-permissions";
      desc = "Start Claude without prompts";
    };
    clu = {
      cmd = "claude update";
      desc = "Check Claude updates";
    };
    cls = {
      cmd = "bunx ccusage";
      desc = "Show Claude usage";
    };
  };

  codexAliases = {
    cx = {
      cmd = "codex";
      desc = "Start Codex";
    };
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
      lib.mapAttrsToList (name: value: "abbr -S -qq ${name}='${value.cmd}'") defs
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

            cl() {
              local args=()
              local use_alt=0
              local use_sub=0

              for arg in "$@"; do
                if [[ "$arg" == "-w" ]]; then
                  use_alt=1
                elif [[ "$arg" == "-s" ]]; then
                  use_sub=1
                else
                  args+=("$arg")
                fi
              done

              if (( use_alt )); then
                ANTHROPIC_API_KEY="''${CLAUDE_CSTYLE_API_KEY}" claude "''${args[@]}"
              elif (( use_sub )); then
                CLAUDE_CONFIG_DIR=~/.claude-sub claude "''${args[@]}"
              else
                claude "''${args[@]}"
              fi
            }

            # cx wraps codex: -s for sub-account (~/.codex-sub),
            # -H for the heavy profile (gpt-5.5 high). Default is gpt-5.4 medium.
            cx() {
              local args=()
              local use_sub=0
              local profile="default"

              for arg in "$@"; do
                case "$arg" in
                  -s) use_sub=1 ;;
                  -H|--heavy) profile="heavy" ;;
                  --spark) profile="spark" ;;
                  *) args+=("$arg") ;;
                esac
              done

              if (( use_sub )); then
                CODEX_HOME=~/.codex-sub codex --profile "$profile" "''${args[@]}"
              else
                codex --profile "$profile" "''${args[@]}"
              fi
            }
    '';
  };
}
