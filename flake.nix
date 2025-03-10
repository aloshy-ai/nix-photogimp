{
  description = "PhotoGIMP customizations for GIMP on macOS - provides Photoshop-like UI and shortcuts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    mac-app-util.url = "github:hraban/mac-app-util";
  };

  outputs = {
    self,
    nixpkgs,
    mac-app-util,
  }: let
    system = "aarch64-darwin";
    pkgs = nixpkgs.legacyPackages.${system};
    lib = pkgs.lib;

    photoGimpSrcInfo = {
      owner = "Diolinux";
      repo = "PhotoGIMP";
      rev = "1.0";
      sha256 = "sha256-l+P0B3qw96P7XH07bezcUL6HTMyEHTHQMJrqzgxcrFI=";
    };

    photoGimpSrc = pkgs.fetchFromGitHub photoGimpSrcInfo;

    # Create a derivation for the PhotoGIMP config
    photoGimpConfigSetup = pkgs.stdenv.mkDerivation {
      name = "photogimp-config-setup";
      src = photoGimpSrc;

      installPhase = ''
        mkdir -p $out/config
        cp -r $src/.var/app/org.gimp.GIMP/config/GIMP/2.10/* $out/config/
        touch $out/config/.photogimp_installed
      '';
    };

    # Get the icon
    photoGimpIcon = pkgs.stdenv.mkDerivation {
      name = "photogimp-icon";
      src = photoGimpSrc;

      installPhase = ''
        mkdir -p $out
        cp $src/.icons/photogimp.png $out/icon.png
      '';
    };

    # Create wrapper script
    gimp-wrapper = let
      configDir = "$HOME/.photogimp-config";
      gimpConfigDir = "$HOME/Library/Application Support/GIMP/2.10";

      # Create a script to handle config setup and cleanup
      configScript = pkgs.writeScript "photogimp-config" ''
        #!${pkgs.bash}/bin/bash

        # Ensure config directories exist
        mkdir -p '${configDir}' "$(dirname '${gimpConfigDir}')"

        # Install PhotoGIMP config if needed
        if [ ! -f '${configDir}/.photogimp_installed' ] || [ -z "$(ls -A '${configDir}')" ]; then
          echo "Setting up PhotoGIMP configuration..."
          rm -rf '${configDir}'/*
          cp -r ${photoGimpConfigSetup}/config/* '${configDir}/' 2>/dev/null || true
        fi

        # Backup and link config
        if [ -e '${gimpConfigDir}' ] && [ ! -L '${gimpConfigDir}' ]; then
          mv '${gimpConfigDir}' '${gimpConfigDir}.backup.$$'
        fi
        ln -sf '${configDir}' '${gimpConfigDir}'

        # Start GIMP
        exec "$@"
      '';
    in
      pkgs.stdenv.mkDerivation {
        name = "gimp-wrapper";
        buildInputs = [pkgs.makeWrapper];

        dontUnpack = true;

        installPhase = ''
          mkdir -p $out/bin $out/share/photogimp
          makeWrapper ${configScript} $out/bin/gimp \
            --add-flags ${pkgs.gimp}/bin/gimp \
            --set PATH ${lib.makeBinPath [pkgs.coreutils pkgs.bash]}
        '';

        meta = {
          description = "GIMP wrapper with PhotoGIMP configuration";
          mainProgram = "gimp";
        };
      };

    # Create a custom package that combines GIMP with our wrapper
    photogimp = pkgs.symlinkJoin {
      name = "photogimp";
      paths = [
        gimp-wrapper
        pkgs.gimp
      ];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        if [ -f $out/bin/gimp-bin ]; then
          # Some systems might have gimp-bin as the actual binary
          mv $out/bin/gimp $out/bin/gimp-original || true
          cp ${gimp-wrapper}/bin/gimp $out/bin/gimp
          chmod +x $out/bin/gimp
        fi

        # Create GIMP.app in our output
        mkdir -p $out/Applications/GIMP.app/Contents/MacOS
        mkdir -p $out/Applications/GIMP.app/Contents/Resources

        # Create Info.plist
        cat > $out/Applications/GIMP.app/Contents/Info.plist << EOF
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>CFBundleExecutable</key>
          <string>gimp</string>
          <key>CFBundleIconFile</key>
          <string>icon.png</string>
          <key>CFBundleIdentifier</key>
          <string>org.gimp.GIMP</string>
          <key>CFBundleName</key>
          <string>GIMP</string>
          <key>CFBundlePackageType</key>
          <string>APPL</string>
          <key>CFBundleShortVersionString</key>
          <string>2.10.38</string>
        </dict>
        </plist>
        EOF

        # Copy icon
        cp ${photoGimpIcon}/icon.png $out/Applications/GIMP.app/Contents/Resources/

        # Create executable
        makeWrapper "$out/bin/gimp" "$out/Applications/GIMP.app/Contents/MacOS/gimp" \
          --set PATH ${lib.makeBinPath [pkgs.coreutils pkgs.bash]}
      '';
      meta = {
        description = "GIMP with PhotoGIMP configuration for a Photoshop-like experience";
        longDescription = ''
          PhotoGIMP is a patch for GIMP 2.10+ that makes it more familiar to Adobe Photoshop users.
          Features include:
          - Tool organization mimicking Photoshop
          - Photoshop-like keyboard shortcuts for Windows
          - New Python filters installed by default
          - New splash screen
          - Maximized canvas space
        '';
        homepage = "https://github.com/Diolinux/PhotoGIMP";
        license = pkgs.lib.licenses.gpl3;
        platforms = pkgs.lib.platforms.darwin;
        mainProgram = "gimp";
      };
    };

    # Create Darwin module
    darwinModule = {
      config,
      lib,
      pkgs,
      ...
    }: {
      options = {
        programs.photogimp = {
          enable = lib.mkEnableOption "PhotoGIMP";
        };
      };

      config = lib.mkIf config.programs.photogimp.enable {
        environment.systemPackages = [photogimp mac-app-util.packages.${system}.default];
        system.activationScripts.installPhotoGIMP = {
          text = ''
            echo "Installing PhotoGIMP.app..."
            sudo rm -rf "/Applications/PhotoGIMP.app"
            sudo cp -r "${photogimp}/Applications/GIMP.app" "/Applications/PhotoGIMP.app"
          '';
        };
      };
    };

    # Create Home Manager module
    homeManagerModule = {
      config,
      lib,
      pkgs,
      ...
    }: {
      options = {
        programs.photogimp = {
          enable = lib.mkEnableOption "PhotoGIMP";
        };
      };

      config = lib.mkIf config.programs.photogimp.enable {
        home.packages = [photogimp mac-app-util.packages.${system}.default pkgs.polkit];
        home.activation.installPhotoGIMP = lib.hm.dag.entryAfter ["writeBoundary"] ''
          echo "Installing PhotoGIMP.app..."
          mkdir -p "$HOME/Applications"
          ${pkgs.polkit}/bin/pkexec rm -rf "$HOME/Applications/PhotoGIMP.app"
          ${pkgs.polkit}/bin/pkexec cp -r "${photogimp}/Applications/GIMP.app" "$HOME/Applications/PhotoGIMP.app"
          ${pkgs.polkit}/bin/pkexec chown -R $USER:staff "$HOME/Applications/PhotoGIMP.app"
          ${pkgs.polkit}/bin/pkexec chmod -R u+w "$HOME/Applications/PhotoGIMP.app"
        '';
      };
    };
  in {
    packages.${system} = {
      photogimp = photogimp;
      default = photogimp;
    };

    nixosModules.default = darwinModule;
    darwinModules.default = darwinModule;
    homeManagerModules.default = homeManagerModule;
  };
}
