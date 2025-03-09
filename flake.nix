{
  description = "Test flake for PhotoGIMP";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-photogimp.url = "path:../nix-photogimp";
  };

  outputs = {
    self,
    nixpkgs,
    nix-photogimp,
  }: let
    system = "aarch64-darwin";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    packages.${system}.default = nix-photogimp.packages.${system}.default;
  };
}
