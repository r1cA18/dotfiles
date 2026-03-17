# プロジェクトごとの開発環境運用ガイド

## 哲学

- ホストマシン（dotfiles）にはプロジェクト固有のツールを入れない
- 各プロジェクトに `flake.nix` + `.envrc` を置いて自己完結させる
- グローバルに入れるのは「どのプロジェクトでも常に使う汎用ツール」だけ

## 基本フロー

### 自分のプロジェクト

```bash
mkdir my-project && cd my-project
git init

# テンプレートでflake.nixを生成
nix flake init -t github:akirak/flake-templates#minimal

# パッケージを追加（flake.nixのbuildInputsを編集）
# ...

# gitに追加してdirenv設定
git add flake.nix
echo "use flake" > .envrc
git add .envrc
direnv allow
```

以後は `cd my-project` するだけで環境が有効になる。

### 他人のプロジェクト（リポジトリを汚さない）

`flake.nix` と `.envrc` はglobal gitignoreに設定済みなので、gitに追跡されない。

```bash
cd someone-elses-project

# flake.nixを自分で追加（gitignore済みなので追跡されない）
cat > flake.nix << 'EOF'
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs = { self, nixpkgs }: let
    system = "aarch64-darwin";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        nodejs_latest
        pnpm
      ];
    };
  };
}
EOF

echo "use flake" > .envrc
direnv allow
```

### 一時的に使いたいだけ

flake.nixも.envrcも不要。

```bash
# そのコマンドだけ実行
nix shell nixpkgs#pnpm --command pnpm install

# シェルに入る（抜けたら消える）
nix shell nixpkgs#pnpm nixpkgs#nodejs_latest
```

## テンプレート一覧（akirak/flake-templates）

```bash
nix flake init -t github:akirak/flake-templates#<name>
```

| テンプレート       | 内容                                      |
| ------------------ | ----------------------------------------- |
| `minimal`          | 何も入っていない最小構成                  |
| `node-typescript`  | Node.js + TypeScript + LSP                |
| `python-uv-simple` | Python + uv + BasedPyright                |
| `rust`             | Rust + rust-analyzer                      |
| `go`               | Go                                        |
| `flake-utils`      | マルチシステム対応（arm/x86）が必要な場合 |

## flake.nixの基本構造

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }: let
    system = "aarch64-darwin";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        # ここにパッケージを追加
        nodejs_latest
        pnpm
        postgresql
      ];

      # シェルに入ったときに実行するスクリプト（任意）
      shellHook = ''
        export DATABASE_URL="postgres://localhost/mydb"
      '';
    };
  };
}
```

## パッケージ検索

```bash
nix search nixpkgs <name>
# または https://search.nixos.org/packages
```

## agent-skills-nixのプロジェクトローカル使用

プロジェクト固有のSkillsが必要な場合（例: Next.jsプロジェクトにvercel/next-skillsを入れる）、
`flake.nix` の `devShell` に組み込むことで `nix develop`（direnv）に入ったとき自動で配置できる。

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    agent-skills.url = "github:Kyure-A/agent-skills-nix";
    some-skills = {
      url = "github:vercel/next-skills";
      flake = false;
    };
  };

  outputs = { nixpkgs, agent-skills, some-skills, ... }: let
    system = "aarch64-darwin";
    pkgs = nixpkgs.legacyPackages.${system};
    agentLib = agent-skills.lib.agent-skills;

    sources = {
      vercel = { path = some-skills; };
    };
    catalog = agentLib.discoverCatalog sources;
    allowlist = agentLib.allowlistFor { inherit catalog sources; enableAll = true; };
    selection = agentLib.selectSkills { inherit catalog allowlist sources; skills = {}; };
    bundle = agentLib.mkBundle { inherit pkgs selection; };
    localTargets = {
      claude = agentLib.defaultLocalTargets.claude // { enable = true; };
    };
  in {
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with pkgs; [ nodejs_latest pnpm ];
      # direnvに入るとSkillsが自動配置される
      shellHook = agentLib.mkShellHook { inherit pkgs bundle; targets = localTargets; };
    };
  };
}
```

## global gitignoreの設定（設定済み）

以下はglobal gitignoreに設定済みなので全リポジトリで追跡されない：

- `flake.nix`
- `flake.lock`
- `.envrc`
- `.direnv/`

自分のプロジェクトでflake.nixをコミットしたい場合は `git add -f flake.nix` で強制追加する。
