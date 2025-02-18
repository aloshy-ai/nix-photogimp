{ pkgs, ... }: {
  services = {
    spice-vdagentd.enable = true;
    tailscale = {
      enable = true;
    };
    openssh = {
        enable = true;               # Enable the OpenSSH daemon
        settings = {
        PermitRootLogin = "no";    # Disable root login
        PasswordAuthentication = false;  # Disable password authentication
        };
        
        # Optionally, configure authorized keys here
        openFirewall = true;  # Alternative way to open SSH port
    };
  };
}