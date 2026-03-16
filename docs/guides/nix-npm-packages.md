# NixでNode系CLIを宣言的に管理

## 概要

Node系CLIはできるだけ Nix package として管理する。`dr` 時の `bun install -g` のような mutable activation は使わない。

## 背景・課題

### 元々の状態

- npm, pnpm, bunでグローバルパッケージがバラバラにインストールされていた
- どこに何が入っているか把握しづらい
- 新しいマシンで環境再現が面倒

### 問題点

- `~/.npm-global/`, `~/.bun/bin` など配置場所が分散する
- activation 成功と実インストール成功がズレやすい
- `|| true` を入れると壊れても気づきにくい

## 解決策

### 方針

1. **nixpkgs にあるCLIはそのまま使う**
2. **nixpkgs にない npm CLI は `nix/pkgs/` で custom package 化する**
3. **skills から参照する補助スクリプトは `agent-skill-path` で解決する**

### 実装

**packages.nix:**

```nix
# 例: nixpkgs にあるもの + custom package
commonPackages = with pkgs; [
  codex
  gemini-cli
  firecrawl-cli
  agent-browser
];
```

custom package は `buildNpmPackage` で npm tarball + `package-lock.json` を固定する:

```nix
buildNpmPackage rec {
  pname = "firecrawl-cli";
  version = "1.9.8";
  src = fetchzip { ... };
  npmDepsHash = "sha256-...";
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';
  dontNpmBuild = true;
  npmInstallFlags = [ "--omit=dev" "--ignore-scripts" ];
}
```

## まとめ

| 項目 | 内容 |
|------|------|
| 管理ファイル | `nix/home-manager/programs/packages.nix` |
| custom package 定義 | `nix/pkgs/<name>/default.nix` |
| lockfile | `nix/pkgs/<name>/package-lock.json` |
| 実行タイミング | Nix build 時 |
| パッケージ追加方法 | nixpkgs か `nix/pkgs/` に追加 |

## 注意点

- `nixpkgs` にあるものを優先する
- npm CLI を custom package 化する時は tarball hash と `npmDepsHash` の両方を固定する
- skill 本体は read-only なので、設定ファイルは XDG 配下に置く
