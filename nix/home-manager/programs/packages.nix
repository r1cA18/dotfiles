{pkgs, ...}: {
  home.packages = with pkgs; [
    # Development
    nodejs_latest
    bun

    # CLI tools
    nodePackages.pnpm
    nodePackages."@antfu/ni"
    ripgrep
    fd
    cloudflared

    # TeX
    texliveFull

    # Fonts
    nerd-fonts.jetbrains-mono
  ];

  home.sessionPath = [
    "$HOME/.npm-global/bin"
    "$HOME/.antigravity/antigravity/bin"
    "$HOME/.local/bin"
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
  };
}
