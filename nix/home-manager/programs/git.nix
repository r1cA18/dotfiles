{ ... }: {
  programs.gh = {
    enable = true;
  };

  programs.git = {
    enable = true;
    ignores = [
      ".DS_Store"
      "*.swp"
      ".direnv"
      ".envrc"
      "flake.nix"
      "flake.lock"
    ];
    settings = {
      user.name = "r1cA18";
      user.email = "r1cA18@proton.me";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = true;
      ghq.root = "~/Develop";
    };
  };
}
