# GitHub auth and commit signing per host

Keys are per host: one auth key, one signing key and one `gh` token per host.

## Mac (default)

- Auth and signing use the 1Password SSH agent (`dotfiles.git.signing.backend = "1password"`)
- `gh` keeps its token in the keychain

## homelab (headless)

- `dotfiles.git.signing.backend = "file"` in `nix/home-manager/hosts/homelab.nix`
- Auth key `~/.ssh/github-auth` (ed25519, no passphrase) through a `Host github.com` block with `IdentitiesOnly yes` and `IdentityAgent none`
- The block is emitted before `Host *`, so the 1Password `IdentityAgent` there does not apply to GitHub
- Signing key `~/.ssh/github-signing` signed by `ssh-keygen`; the include file is written only when `~/.ssh/github-signing.pub` exists
- `gh` token in `~/.config/gh/hosts.yml` (`--insecure-storage`)
- `allowed_signers` lists the Mac key and the homelab signing public key
- The vault uses these host-wide settings; there is no vault-specific key

## One-time setup on a new file-backend host

1. Create keys: `ssh-keygen -t ed25519 -N '' -C '<host> github auth' -f ~/.ssh/github-auth` and the same for `~/.ssh/github-signing`
2. Register the auth key and the signing key on GitHub (`gh ssh-key add`, with `--type signing` for the signing key)
3. Log in `gh` with `--insecure-storage`
4. Apply the dotfiles and verify from a clean systemd context: `systemd-run --user --wait --pipe ssh -T git@github.com`
