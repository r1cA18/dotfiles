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
      desc = "Go to dotfiles (compatibility name; prefer dot)";
    };
    update-all = {
      cmd = "nix flake update --flake ~/dotfiles && update-github-apps && update-claude-code && update-codex && update-antigravity && update-ccspace";
      desc = "Update flake + GitHub apps + Claude Code + Codex + Antigravity + ccspace";
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
      help = "まず db でbuildを確認してから dr で適用してください。\n\n  db\n  dr\n\n適用前の状態へ戻す場合: dot-rollback";
    };
    db = {
      cmd = "nh darwin build ~/dotfiles -H ${hostname}";
      desc = "Build Darwin config";
    };
    dp = {
      cmd = "darwin-rebuild switch --rollback";
      desc = "Rollback Darwin config (compatibility name; prefer dot-rollback)";
    };
    dot-rollback = {
      cmd = "darwin-rebuild switch --rollback";
      desc = "Rollback Darwin config";
    };
  };

  nixLinuxAliases = {
    dr = {
      cmd = "nh home switch ~/dotfiles -c ${linuxConfigName}";
      desc = "Apply Home Manager config";
      help = "まず db でbuildを確認してから dr で適用してください。\n\n  db\n  dr\n\n世代を確認する場合: dot-generations";
    };
    db = {
      cmd = "nh home build ~/dotfiles -c ${linuxConfigName}";
      desc = "Build Home Manager config";
    };
    dp = {
      cmd = "home-manager generations";
      desc = "List Home Manager generations (compatibility name; prefer dot-generations)";
    };
    dot-generations = {
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
  #
  # Account switching used to go through clp (archived; see
  # archive/agent-profile-manager/). ccspace (docs/guides/ccspace.md) replaces
  # it with per-account launcher shims (e.g. cc-work); cl reproduces the old
  # picker via ccspace-pick (ccspace.nix).
  claudeAliases = {
    cl = {
      cmd = "ccspace-pick claude";
      desc = "Start Claude Code with account picker";
    };
    clw = {
      cmd = "ANTHROPIC_API_KEY=\${CLAUDE_CSTYLE_API_KEY} claude";
      desc = "Start Claude with work API key";
    };
    # session actions (primary account)
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
    clgc = {
      cmd = "clgpt --continue";
      desc = "Continue last GPT-backed Claude session";
    };
    clgr = {
      cmd = "clgpt --resume";
      desc = "Resume GPT-backed Claude session from picker";
    };
    cld = {
      cmd = "claude --dangerously-skip-permissions";
      desc = "Start Claude without prompts";
    };
    clgd = {
      cmd = "clgpt --dangerously-skip-permissions";
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

  # Codex abbreviations (primary account). Named model layers are loaded from
  # the default CODEX_HOME as heavy.config.toml / spark.config.toml.
  # Account switching used to go through cxp (archived; see
  # archive/agent-profile-manager/) and is now ccspace launcher shims
  # (e.g. cx-work); cx reproduces the old picker via ccspace-pick (ccspace.nix).
  codexAliases = {
    cx = {
      cmd = "ccspace-pick codex";
      desc = "Start Codex with account picker";
    };
    cxh = {
      cmd = "codex --profile heavy";
      desc = "Start Codex with heavy profile (gpt-5.5 high)";
    };
    cxsp = {
      cmd = "codex --profile spark";
      desc = "Start Codex with spark profile";
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

  workspaceAliases = {
    ws = {
      cmd = "workspace";
      desc = "Manage workspaces (init / clone / add / sync / status)";
      help = ''
        GitとBunで利用できます。配布先でNixは必須ではありません。

        作成とrepo追加:
          ws init ~/Workspaces/product
          cd ~/Workspaces/product
          ./ws add <repo-URL> web
          ./ws status
          ./ws codex

        共有workspaceの取得:
          ws clone <workspace-URL> ~/Workspaces/product
        wsがない環境:
          git clone <workspace-URL> product
          cd product
          ./ws sync

        親repoはrepos.jsonと共通指示を管理します。
        子repoのcommit・pullは各repoで行ってください。
        syncは不足repoを取得します。既存repoのpullは行いません。
        workspaceへの移動: wsg

        account profileの選択と保存:
          ws profile codex
          ws profile claude
        設定確認: ws profile
        解除: ws profile codex --clear
        保存先は親repoの.git/configです。以後のws codex・ws claudeに適用します。
      '';
    };
  };

  # Executables do not become abbreviations. Keep them visible in h without
  # adding shell aliases that could shadow the real commands.
  canonicalCommands = {
    ccspace = {
      cmd = "ccspace <command>";
      desc = "Manage Claude/Codex account spaces and launchers";
      help = ''
        accountごとにconfig homeを分けたlauncher (cc-<name> / cx-<name>) を管理します。
          ccspace list
          ccspace add cc-work
          ccspace usage
          ccspace doctor
        詳細: docs/guides/ccspace.md
        workspaceから起動する場合: ./ws claude / ./ws codex
      '';
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

  shellTools = {
    h = {
      cmd = "h [pattern]";
      desc = "Browse personal tool help (filter with an argument)";
      help = "h: 対話terminalで検索とpreviewを開きます。\nh workspace: 説明一覧を絞り込みます。\nh | less: 一覧を出力します。\nhp workspace: workspaceを検索した状態でpickerを開きます。\nhv ws: コマンドの展開先を確認します。\n\n選択したコマンドは実行されません。";
    };
    hp = {
      cmd = "hp [query]";
      desc = "Search help with fzf and preview usage examples";
    };
    hv = {
      cmd = "hv [pattern]";
      desc = "List command expansions";
    };
    devg = {
      cmd = "devg";
      desc = "Pick a development repository and change directory";
    };
    wsg = {
      cmd = "wsg [root]";
      desc = "Pick a workspace and change directory";
      help = "既定の探索先は ~/Workspaces です。\n  wsg\n  wsg /path/to/workspaces\n\nrepos.jsonがあるworkspaceを選択できます。\n子repo・.git・node_modulesの内部は探索しません。\nEscで移動を取り消します。";
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
      defs = (if isDarwin then dirDarwinAliases else dirLinuxAliases) // {
        inherit (shellTools) devg wsg;
      };
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
      title = "Workspace";
      defs = workspaceAliases;
    }
    {
      title = "Agent Commands";
      defs = canonicalCommands;
    }
    {
      title = "Help";
      defs = removeAttrs shellTools [
        "devg"
        "wsg"
      ];
    }
  ];

  abbrDefs =
    generalAliases
    // nixCommonAliases
    // (if isDarwin then nixDarwinAliases else nixLinuxAliases)
    // (if isDarwin then dirDarwinAliases else dirLinuxAliases)
    // claudeAliases
    // codexAliases
    // workspaceAliases;

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
  helpEntries = lib.concatMapStringsSep "\n" (
    section:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: value:
        lib.escapeShellArg (
          "${name}\t${section.title}\t${value.desc}\t"
          + "${name} — ${value.desc}\n\n${value.cmd}"
          + lib.optionalString (value ? help) "\n\n${value.help}"
        )
      ) section.defs
    )
  ) helpSections;
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

      typeset -g _dotfiles_help_descriptions=${lib.escapeShellArg helpTextDescriptions}
      typeset -g _dotfiles_help_commands=${lib.escapeShellArg helpTextCommands}
      typeset -ga _dotfiles_help_entries=( ${helpEntries} )
      typeset -gA _dotfiles_managed_abbrs=( ${managedAbbrPairs} )
      ${builtins.readFile ./zsh-tools.zsh}

    '';
  };
}
