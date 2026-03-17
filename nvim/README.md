# nvim

LazyVim をベースにした最小構成。

- UI と editor 挙動は `nvim/` 側で管理
- LSP / formatter / native dependency は Nix 側で供給
- `mason` は自動インストール用途では使わず、PATH 上のツールを優先
