# Shell for an activation step that merges Nix-managed keys into a client's
# writable config file (see agents/scripts/merge-managed.py). The client may
# rewrite the file; keys Nix does not manage are kept, and a key Nix stops
# managing is removed. The step never fails the activation.
{ pkgs, lib }:
let
  python = pkgs.python3.withPackages (p: [ p.tomli-w ]);
in
{
  format,
  target,
  fragment,
  name,
}:
''
  run ${lib.getExe python} ${../../agents/scripts/merge-managed.py} ${format} "${target}" \
    ${pkgs.writeText "${name}-managed.json" (builtins.toJSON fragment)} \
    "''${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/managed/${name}.json" \
    || echo "dotfiles: merging ${target} failed" >&2
''
