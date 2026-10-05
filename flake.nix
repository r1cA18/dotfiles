{
  description = "r1ca18's cross-platform Nix configuration (macOS & Linux)";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # nix-darwin (macOS only)
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # home-manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # agent-skills-nix (declarative Agent Skills management)
    agent-skills-nix = {
      url = "github:Kyure-A/agent-skills-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Claude Code -> ChatGPT/Codex protocol proxy
    claude-code-proxy.url = "github:raine/claude-code-proxy/v0.1.35";
    claude-code-proxy.inputs.nixpkgs.follows = "nixpkgs";

    # nix-index-database (for comma)
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    # Herdr terminal multiplexer
    herdr.url = "github:herdrdev/herdr/v0.7.5";
    herdr.inputs.nixpkgs.follows = "nixpkgs";

    # Anthropic official skills
    anthropic-skills.url = "github:anthropics/skills";
    anthropic-skills.flake = false;

    # Selected portable skills from the official legacy catalog.
    # The successor openai/plugins does not currently ship these CLI workflows.
    openai-skills.url = "github:openai/skills";
    openai-skills.flake = false;

    # Focused property-based testing guidance; no marketplace-wide activation.
    trailofbits-skills.url = "github:trailofbits/skills";
    trailofbits-skills.flake = false;

    # difit skills
    difit-skills.url = "github:yoshiko-pg/difit";
    difit-skills.flake = false;

    # App Store screenshot generation skill
    app-store-screenshots.url = "github:ParthJadhav/app-store-screenshots";
    app-store-screenshots.flake = false;

    # NotebookLM integration skill (query notebooks from Claude Code)
    notebooklm-skill.url = "github:PleasePrompto/notebooklm-skill";
    notebooklm-skill.flake = false;

    # Typst document authoring skills
    typst-skills.url = "github:apcamargo/typst-skills";
    typst-skills.flake = false;

    # taste-skill: anti-slop frontend skill collection (13 variants)
    taste-skill.url = "github:Leonxlnx/taste-skill";
    taste-skill.flake = false;

    # text-to-lottie: author Lottie (Bodymovin) animations in a local skia player
    lottie.url = "github:diffusionstudio/lottie";
    lottie.flake = false;

    # Codex plugin: ask local Claude Code from Codex
    claude-plugin-codex.url = "github:yanchuk/claude-plugin-codex";
    claude-plugin-codex.flake = false;

    # Orca skills
    orca-skills.url = "github:stablyai/orca";
    orca-skills.flake = false;

    # treefmt-nix (unified formatter)
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    # git-hooks.nix (pre-commit hooks)
    git-hooks-nix.url = "github:cachix/git-hooks.nix";
    git-hooks-nix.inputs.nixpkgs.follows = "nixpkgs";

  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      # Supported systems (macOS + Linux)
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

      development = forAllSystems (
        system:
        import ./nix/flake/development.nix {
          inherit inputs system;
          pkgs = nixpkgs.legacyPackages.${system};
        }
      );

      # Backwards-compatible project dev-shell helper.
      # Usage in project flake.nix:
      #   inputs.dotfiles.url = "git+file:///Users/r1ca18/dotfiles";
      #   devShells.default = dotfiles.lib.${system}.mkShellWithSkills { };
      mkDevShellLib =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        import ./nix/lib/dev-shell.nix { inherit pkgs; };

    in
    {
      # Small project dev-shell helper. Agent skills are managed globally.
      lib = forAllSystems mkDevShellLib;

      # Custom packages
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          mkGithubReleaseApp = pkgs.callPackage ./nix/lib/github-app.nix { };
        in
        import ./nix/pkgs pkgs
        // nixpkgs.lib.optionalAttrs pkgs.stdenv.isDarwin {
          recordly = pkgs.callPackage ./nix/pkgs/recordly { inherit mkGithubReleaseApp; };
        }
      );

      formatter = forAllSystems (system: development.${system}.formatter);
      checks = forAllSystems (system: development.${system}.checks);
      devShells = forAllSystems (system: development.${system}.devShells);

      apps = forAllSystems (
        system:
        import ./nix/flake/apps.nix {
          inherit inputs system;
          pkgs = nixpkgs.legacyPackages.${system};
          formatter = development.${system}.formatter;
        }
      );

      # Custom overlays
      overlays = import ./nix/overlays;
    }
    // import ./nix/flake/configurations.nix { inherit inputs; };
}
