pkgs:
let
  mdv = pkgs.rustPlatform.buildRustPackage rec {
    pname = "mdv";
    version = "0.1.1-unstable-2026-04-11";

    src = pkgs.fetchFromGitHub {
      owner = "posaune0423";
      repo = "mdv";
      rev = "739511ec80d6b2bc552febd47ffce47e1a9d3368";
      hash = "sha256-5pKZ9Y1XKzB4NTqwRZ4WIXJ4sgdzclLFWoCfWZcpDkI=";
    };

    cargoHash = "sha256-BbVOc87Vrth5W9tU1N0/hbefUwM7C4EQyeDqQBEWfsw=";

    doCheck = false;

    installCheckPhase = ''
      runHook preInstallCheck
      "$out/bin/mdv-real" --version >/dev/null
      "$out/bin/mdv" --version >/dev/null
      runHook postInstallCheck
    '';

    postInstall = ''
      mv "$out/bin/mdv" "$out/bin/mdv-real"

      cat > "$out/bin/mdv" <<EOF
      #!${pkgs.runtimeShell}
      set -euo pipefail

      if [ "''${1-}" = "update" ] || [ "''${1-}" = "upgrade" ]; then
        echo "mdv was installed via Nix; update it through this flake instead of 'mdv update'." >&2
        exit 1
      fi

      exec "$out/bin/mdv-real" "\$@"
      EOF

      chmod +x "$out/bin/mdv"
    '';

    meta = with pkgs.lib; {
      description = "Browser-quality Markdown viewer for the terminal";
      homepage = "https://github.com/posaune0423/mdv";
      license = licenses.mit;
      mainProgram = "mdv";
      platforms = platforms.unix;
    };
  };
in
{
  agent-browser = pkgs.callPackage ./agent-browser { };
  firecrawl-cli = pkgs.callPackage ./firecrawl-cli { };
  inherit mdv;
  stitch-mcp = pkgs.callPackage ./stitch-mcp { };
}
