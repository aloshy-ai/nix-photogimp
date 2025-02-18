{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    gh
    git
    bun
    docker
    devbox
    vscode
    nodejs
    busybox
    tailscale
    python3Full
    docker-compose
  ];
}
