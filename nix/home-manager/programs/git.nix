{
  pkgs,
  lib,
  config,
  ...
}:
let
  signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEDYx2wE/80gbRnZBXJgHKTacQTIFrvrpcBfy6PKoZ9x";
  userEmail = "r1cA18@proton.me";
  allowedSignersPath = "${config.xdg.configHome}/git/allowed_signers";

  baseSettings = {
    user.name = "r1cA18";
    user.email = userEmail;
    init.defaultBranch = "main";
    push.autoSetupRemote = true;
    push.useForceIfIncludes = true;
    pull.rebase = true;
    fetch.prune = true;
    fetch.pruneTags = true;
    rebase.autoSquash = true;
    rebase.updateRefs = true;
    rerere.enabled = true;
    diff.algorithm = "histogram";
    merge.conflictstyle = "zdiff3";
    commit.verbose = true;
    branch.sort = "-committerdate";
    column.ui = "auto";
    help.autocorrect = "prompt";
    ghq.root = "~/Develop";
  };

  # 1Password SSH agent による commit/tag 署名 (両OS)。
  # op-ssh-sign のパスのみ OS 別。署名設定は静的に書かず、activation で
  # op-ssh-sign の存在を確認してから include ファイルに書き出す。
  # 1Password 未導入のマシン (初期セットアップ直後の Ubuntu 等) では
  # include が空になり、commit は無署名で通る。導入後に dr すれば有効化。
  opSshSign =
    if pkgs.stdenv.isDarwin then
      "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
    else
      "/opt/1Password/op-ssh-sign";

  signingIncludePath = "${config.xdg.configHome}/git/1password-signing";

  # 署名設定の中身を store ファイルに固める。activation では install で
  # コピーするだけにする (heredoc + /dev/stdin だと coreutils install が
  # fifo を "replaced while being copied" と誤検知して skip するため)。
  signingConfigFile = pkgs.writeText "git-1password-signing" ''
    [user]
      signingkey = ${signingKey}
    [commit]
      gpgsign = true
    [tag]
      gpgsign = true
    [gpg]
      format = ssh
    [gpg "ssh"]
      program = ${opSshSign}
      allowedSignersFile = ${allowedSignersPath}
  '';
in
{
  programs = {
    gh.enable = true;

    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
      };
    };

    git = {
      enable = true;
      ignores = [
        ".DS_Store"
        "*.swp"
        ".direnv"
        ".envrc"
        ".claude/skills"
        ".claude/settings.local.json"
        "__pycache__"
        "*.pyc"
        "node_modules"
        ".venv"
        "result"
      ];
      settings = lib.recursiveUpdate baseSettings {
        # 存在しない include は git が黙って無視するので、署名無効時も無害
        include.path = signingIncludePath;
      };
    };
  };

  # ローカル検証用の信頼鍵リスト (両OS)
  xdg.configFile."git/allowed_signers".text = "${userEmail} ${signingKey}\n";

  # op-ssh-sign があるマシンだけ署名を有効化 (self-healing: 1Password 導入後の
  # dr で自動有効化、アンインストールしたら次の dr で自動無効化)
  home.activation.gitSigningInclude = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -x "${opSshSign}" ]; then
      run install -D -m 644 "${signingConfigFile}" "${signingIncludePath}"
    else
      run rm -f "${signingIncludePath}"
      echo "git signing disabled: ${opSshSign} not found (install 1Password desktop and re-run dr)"
    fi
  '';
}
