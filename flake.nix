{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: {

    # Add NixOS configuration
    nixosConfigurations = {
      utmnix = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
          ./configuration.nix
          ./nix/networking.nix
          ./nix/packages.nix
          ./nix/services.nix
          ./nix/users.nix
          ./nix/virtualisation.nix
          ./nix/config.nix
        ];
      };
    };

  };
}
