# Project dev-shell builder for this dotfiles workflow.
#
# Agent skills are global, so this wrapper only preserves the old
# mkShellWithSkills entry point for existing project flakes.
#
# Base shell uses mkShellNoCC, NOT mkShell, on purpose:
#
#   On Darwin, pkgs.mkShell pulls the nixpkgs C toolchain into the shell even
#   with zero buildInputs. That toolchain exports DEVELOPER_DIR/SDKROOT pointing
#   at the nixpkgs apple-sdk (macOS SDK only) and shadows `xcrun`/`clang` with
#   nix builds. Inside such a shell the system Xcode toolchain is hidden, so
#   swift, swiftc, xcodebuild, simctl, the iOS/iPadOS simulator SDKs, and mdv's
#   WebKit snapshot helper all break with "tool 'swift' not found" /
#   "unable to find sdk: 'iphonesimulator'".
#
#   mkShellNoCC uses stdenvNoCC, so it pulls no apple-sdk / cc wrapper: it leaves
#   DEVELOPER_DIR/SDKROOT unset and keeps `xcrun`/`clang` resolving to system
#   Xcode. Prebuilt nix tooling (python.withPackages, node, CLI tools) needs no
#   in-shell compiler, so nothing is lost. If a project genuinely needs to
#   compile native code with nix's clang in-shell, it should pass an explicit
#   compiler (e.g. nativeBuildInputs = [ pkgs.clang ]) for that project.
{
  pkgs,
}:
{
  mkShellWithSkills =
    {
      selectedPacks ? [ ],
      extraSkills ? [ ],
      extraPlugins ? [ ],
      extraClaudePlugins ? [ ],
      extraCodexPlugins ? [ ],
      extraCodexMarketplaces ? { },
      extraMcpServers ? { },
      ...
    }@args:
    pkgs.mkShellNoCC (
      builtins.removeAttrs args [
        "selectedPacks"
        "extraSkills"
        "extraPlugins"
        "extraClaudePlugins"
        "extraCodexPlugins"
        "extraCodexMarketplaces"
        "extraMcpServers"
      ]
    );
}
