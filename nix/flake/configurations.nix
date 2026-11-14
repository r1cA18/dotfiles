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
    }:
    nix-darwin.lib.darwinSystem {
      inherit system;
      specialArgs = {
        inherit
          inputs
          username
          hostname
          system
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
                ;
            };
            users.${username} = {
              imports = [
                agent-skills-nix.homeManagerModules.default
                nix-index-database.homeModules.nix-index
                # Option types and projection of the capability catalog. From
                # the private r1hn input, so only hosts that use r1hn import it
                # (CI never fetches it); see programs/capabilities.nix.
                inputs.r1hn.homeManagerModules.capabilities
                (import ../home-manager/home.nix)
                # The Mac is an r1hn worker like homelab: r1hnd and T3 Code
                # as launchd agents.
                ../home-manager/programs/r1hnd-service.nix
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
    };
    modules = [
      agent-skills-nix.homeManagerModules.default
      nix-index-database.homeModules.nix-index
      # homelab runs r1hnd (hosts/homelab.nix), so r1hn projects the catalog
      # into its accounts as on macOS.
      inputs.r1hn.homeManagerModules.capabilities
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
