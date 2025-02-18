{ ... }:

{
  networking = {
    # Set hostname (you may want to change this)
    hostName = "utmnix";

    # Enable NetworkManager for general network management
    networkmanager.enable = true;

    # Configure the static IP address
    useDHCP = false;  # Disable DHCP globally
    interfaces = {
      enp0s1 = {
        useDHCP = false;
        ipv4.addresses = [{
          address = "192.168.69.69";
          prefixLength = 24;
        }];
      };
    };

    # Set default gateway (adjust if different)
    defaultGateway = "192.168.69.1";

    # Configure DNS servers (example using Google DNS)
    nameservers = [ "8.8.8.8" "8.8.4.4" ];
  };

  # Firewall configuration
  networking.firewall = {
    enable = true;
    allowPing = true;
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
  };
}