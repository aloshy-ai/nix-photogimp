{ ... }: {
  users = {
    users = {
      aloshy = {
        isNormalUser = true;
        extraGroups = [ "wheel" "docker" "tailscale" ];
        hashedPassword = "$6$OF89tQYOvaEHKCfx$KYSdQu/GHroUMovkUKUqbvUpEM51MurUpLob6E9YiEMWxvABDsrfACQxej02f9xuV5.HnNtMmpEoLDeAqCZfB1";
        openssh = {
            authorizedKeys = {
                keys = [
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMyizay27AAwIXA84BU9bgmb6/YA4cR8WpJgmPr1Ebvz aloshy@aloshys-MacBook-Pro.local"
                ];
            };
        };
      };
    };
  };
}