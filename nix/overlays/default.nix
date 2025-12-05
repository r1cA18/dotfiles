# Custom overlays
{inputs, ...}: {
  # Custom packages from ./pkgs directory
  additions = final: _prev: import ../pkgs final.pkgs;

  # Modifications to existing packages
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    # Example: patch an existing package
    # example = prev.example.overrideAttrs (oldAttrs: {
    #   ...
    # });
  };

  # Access stable packages via pkgs.stable
  stable-packages = final: _prev: {
    stable = import inputs.nixpkgs-stable {
      system = final.system;
      config.allowUnfree = true;
    };
  };
}




