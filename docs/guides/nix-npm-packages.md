# NixでnpmパッケージをBunで宣言的に管理

## 概要

グローバルnpmパッケージをNixで宣言的に管理し、`dr`実行時に自動でインストール・更新する仕組み。

## 背景・課題

### 元々の状態

- npm, pnpm, bunでグローバルパッケージがバラバラにインストールされていた
- どこに何が入っているか把握しづらい
- 新しいマシンで環境再現が面倒

### 問題点

- `~/.npm-global/`, `~/.bun/install/global/`, pnpmのグローバルなど場所が分散
- 手動でインストールが必要
- バージョン管理ができない

## 解決策

### 方針

1. **bunに統一** - 高速で、`~/.bun/bin`がPATHに入っている
2. **Nixで宣言的に管理** - packages.nixにリストを定義
3. **activation scriptで自動インストール** - `dr`時に自動実行

### 実装

**packages.nix:**

```nix
# bunでグローバルインストールするnpmパッケージ
globalNpmPackages = [
  "@anthropic-ai/claude-code"
  "@google/gemini-cli"
  "@openai/codex"
  "agent-browser"
  "@ast-grep/cli"
];

# dr実行時にbunでグローバルパッケージをインストール・更新
home.activation.installGlobalNpmPackages = lib.hm.dag.entryAfter ["writeBoundary"] ''
  export PATH="${pkgs.bun}/bin:$PATH"
  echo "Installing global npm packages via bun..."
  ${pkgs.bun}/bin/bun install -g ${lib.concatStringsSep " " globalNpmPackages} || true
'';
```

### スキル/プラグインのインストール

curlやbunxで外部スキルもactivation scriptで管理：

```nix
# UI Skills
home.activation.installUiSkills = lib.hm.dag.entryAfter ["writeBoundary"] ''
  echo "Installing UI Skills..."
  export PATH="${pkgs.curl}/bin:${pkgs.coreutils}/bin:$PATH"
  ${pkgs.curl}/bin/curl -fsSL https://ui-skills.com/install | ${pkgs.bash}/bin/bash || true
'';

# Agent Skills (vercel-labs)
home.activation.installAgentSkills = lib.hm.dag.entryAfter ["writeBoundary"] ''
  echo "Installing Agent Skills..."
  export PATH="${pkgs.bun}/bin:$PATH"
  ${pkgs.bun}/bin/bunx skills i vercel-labs/agent-skills || true
'';
```

## まとめ

| 項目 | 内容 |
|------|------|
| 管理ファイル | `nix/home-manager/programs/packages.nix` |
| インストール先 | `~/.bun/bin` |
| 実行タイミング | `dr`（darwin-rebuild switch）時 |
| パッケージ追加方法 | `globalNpmPackages`リストに追加 |

## 注意点

- nixpkgsにあるnpmパッケージは`nodePackages.xxx`で入れる方が純粋
- 頻繁に更新されるCLI（claude-codeなど）はbunの方が最新を追いやすい
- `|| true`で失敗してもdr全体は止まらないようにする
