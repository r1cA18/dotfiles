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
  # op-ssh-sign のパスのみ OS 別。Linux は 1Password desktop 導入が前提
  # (未導入だと commit.gpgsign により全 commit が署名失敗するため、
  #  1Password を入れてから dr すること)。
  opSshSign =
    if pkgs.stdenv.isDarwin then
      "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
    else
      "/opt/1Password/op-ssh-sign";

  signingSettings = {
    user.signingkey = signingKey;
    commit.gpgsign = true;
    tag.gpgsign = true;
    gpg.format = "ssh";
    gpg.ssh.program = opSshSign;
    gpg.ssh.allowedSignersFile = allowedSignersPath;
  };
in
{
  programs.gh.enable = true;

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      side-by-side = true;
      line-numbers = true;
    };
  };

  programs.git = {
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
    settings = lib.recursiveUpdate baseSettings signingSettings;
  };

  # ローカル検証用の信頼鍵リスト (両OS)
  xdg.configFile."git/allowed_signers".text = "${userEmail} ${signingKey}\n";
}
