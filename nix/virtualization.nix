{ ... }: {
  virtualisation = {
    docker = {
      enable = true;
    };
    qemu = {
      networkingOptions = [
        "-net nic,netdev=user.0,model=virtio"
        "-netdev user,id=user.0,net=192.168.69.0/24,\${QEMU_NET_OPTS:+,$QEMU_NET_OPTS}"
      ];
    };
  };
}