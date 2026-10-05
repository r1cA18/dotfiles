# Host composition; program settings stay in their existing modules.
{ inputs }:
let
  inherit (inputs)
    nixpkgs
    nix-darwin
    home-manager
    agent-skills-nix
    nix-index-database
    ;
  # Helper to build a darwin configuration
  mkDarwinConfig =
    {
      hostname,
      username,
      system ? "aarch64-darwin",
      nixEnable ? true,
      profile ? "workstation",
    }:
    nix-darwin.lib.darwinSystem {
      inherit system;
      specialArgs = {
        inherit
          inputs
          username
          hostname
          system
          nixEnable
          profile
          ;
      };
      modules = [
        ../darwin/configuration.nix
        home-manager.darwinModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "hm-backup";
            extraSpecialArgs = {
              inherit
                inputs
                username
                hostname
                profile
                ;
            };
            users.${username} = {
              imports = [
                agent-skills-nix.homeManagerModules.default
                nix-index-database.homeModules.nix-index
                (import ../home-manager/home.nix)
              ];
            };
          };
        }
      ];
    };
in
{
  # Darwin configurations (macOS)
  # Build with: nh darwin switch . -H <hostname>
  darwinConfigurations = {
    RMB = mkDarwinConfig {
      hostname = "RMB";
      username = "r1ca18";
    };
    "MBP187-Z" = mkDarwinConfig {
      hostname = "MBP187-Z";
      username = "mbp187";
      profile = "server";
      nixEnable = false;
    };
  };

  # Standalone Home Manager configuration used by server-apply.
  homeConfigurations."r1ca18@homelab" = home-manager.lib.homeManagerConfiguration {
    pkgs = import nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
    extraSpecialArgs = {
      inherit inputs;
      username = "r1ca18";
      hostname = "homelab";
      profile = "workstation";
    };
    modules = [
      agent-skills-nix.homeManagerModules.default
      nix-index-database.homeModules.nix-index
      ../home-manager/hosts/homelab.nix
      {
        nixpkgs.config.allowUnfree = true;
        nixpkgs.overlays = [
          inputs.self.overlays.additions
        ];
      }
    ];
  };
}
