{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: {

    # Add NixOS configuration
    nixosConfigurations = {
      hostname = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ./configuration.nix
          ./nix/host.nix
          ./nix/packages.nix
          ./nix/services.nix
          ./nix/users.nix
          ./nix/virtualization.nix
        ];
      };
    };

  };
}
