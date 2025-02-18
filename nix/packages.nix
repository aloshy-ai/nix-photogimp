{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    git
    tailscale
    docker
    docker-compose
  ];
}
