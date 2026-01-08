{pkgs, ...}: let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;

  # 共通パッケージ (両OS)
  commonPackages = with pkgs; [
    # Development
    nodejs_latest
    bun

    # CLI tools
    nodePackages.pnpm
    nodePackages."@antfu/ni"
    ripgrep
    fd
    cloudflared
    tmux
  ];

  # macOS専用パッケージ
  darwinPackages = with pkgs; [
    # TeX (重いのでmacOSのみ)
    texliveFull

    # Fonts (macOS側でレンダリングするので必要)
    nerd-fonts.jetbrains-mono
  ];

  # Linux/Server専用パッケージ
  linuxPackages = with pkgs; [
    # 必要に応じて追加
    # htop
    # tmux
  ];
in {
  home.packages =
    commonPackages
    ++ (if isDarwin then darwinPackages else linuxPackages);

  home.sessionPath = [
    "$HOME/.npm-global/bin"
    "$HOME/.antigravity/antigravity/bin"
    "$HOME/.local/bin"
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
  };
}
