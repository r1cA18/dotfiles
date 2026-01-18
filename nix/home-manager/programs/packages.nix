{
  pkgs,
  lib,
  ...
}: let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;

  # 共通パッケージ (両OS)
  commonPackages = with pkgs; [
    # Development
    nodejs_latest
    bun
    uv

    # CLI tools
    nodePackages.pnpm
    nodePackages."@antfu/ni"
    ripgrep
    fd
    cloudflared
    tmux
    ffmpeg
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

  # bunでグローバルインストールするnpmパッケージ
  # `dr`実行時に自動でインストール・更新される
  globalNpmPackages = [
    "@anthropic-ai/claude-code"
    "@google/gemini-cli"
    "@openai/codex"
    "agent-browser"
    "@ast-grep/cli"
  ];
in {
  home.packages =
    commonPackages
    ++ (if isDarwin then darwinPackages else linuxPackages);

  home.sessionPath = [
    "$HOME/.bun/bin"
    "$HOME/.npm-global/bin"
    "$HOME/.antigravity/antigravity/bin"
    "$HOME/.local/bin"
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  # dr実行時にbunでグローバルパッケージをインストール・更新
  home.activation.installGlobalNpmPackages = lib.hm.dag.entryAfter ["writeBoundary"] ''
    export PATH="${pkgs.bun}/bin:$PATH"
    echo "Installing global npm packages via bun..."
    ${pkgs.bun}/bin/bun install -g ${lib.concatStringsSep " " globalNpmPackages} || true
  '';

  # UI Skills (Claude Code等のスキルファイル)
  home.activation.installUiSkills = lib.hm.dag.entryAfter ["writeBoundary"] ''
    echo "Installing UI Skills..."
    export PATH="${pkgs.curl}/bin:${pkgs.coreutils}/bin:$PATH"
    ${pkgs.curl}/bin/curl -fsSL https://ui-skills.com/install | ${pkgs.bash}/bin/bash || true
  '';

  # Agent Skills (vercel-labs)
  home.activation.installAgentSkills = lib.hm.dag.entryAfter ["writeBoundary"] ''
    echo "Installing Agent Skills..."
    export PATH="${pkgs.bun}/bin:${pkgs.nodejs}/bin:${pkgs.git}/bin:$PATH"
    ${pkgs.bun}/bin/bunx skills i vercel-labs/agent-skills || true
  '';
}
