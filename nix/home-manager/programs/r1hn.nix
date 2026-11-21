{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  # r1hn comes from a private flake input (see flake.nix). Flake inputs are
  # fetched only when read, so a host with this switch off never needs access
  # to that repository. CI stays off; homelab turns it on in r1hnd-service.nix.
  options.dotfiles.r1hn.enable = lib.mkOption {
    type = lib.types.bool;
    default = pkgs.stdenv.hostPlatform.isDarwin;
    description = "Install r1hn and point cl / cx at it.";
  };

  config = lib.mkIf config.dotfiles.r1hn.enable {
    home.packages =
      let
        harness = inputs.r1hn.packages.${pkgs.stdenv.hostPlatform.system};
      in
      [
        harness.r1hn
        # Claude's structured sessions run through the official ACP adapter,
        # which starts the owner's own `claude` (r1hn sets the executable).
        harness.claude-agent-acp
        # Devin's runtime (`devin acp`), the vendor binary pinned by the harness.
        harness.devin
        # pi runs metered accounts only (API keys), never a subscription.
        pkgs.pi-coding-agent
      ];
  };
}
