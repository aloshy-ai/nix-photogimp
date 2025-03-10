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
    gimp-wrapper = pkgs.writeShellApplication {
      name = "gimp";
      runtimeInputs = [pkgs.gimp];
      text = ''
        set -e

        # Create a temporary directory for PhotoGIMP config
        PHOTOGIMP_CONFIG_DIR="$HOME/.photogimp-config"
        GIMP_CONFIG_DIR="$HOME/Library/Application Support/GIMP/2.10"

        # Ensure PhotoGIMP config directory exists
        mkdir -p "$PHOTOGIMP_CONFIG_DIR"

        # Copy PhotoGIMP files to our managed location if not already there
        if [ ! -f "$PHOTOGIMP_CONFIG_DIR/.photogimp_installed" ]; then
          echo "Setting up PhotoGIMP configuration (one-time setup)..."
          cp -r ${photoGimpConfigSetup}/config/* "$PHOTOGIMP_CONFIG_DIR/" 2>/dev/null || true
        fi

        # Create parent directory for GIMP config if it doesn't exist
        mkdir -p "$(dirname "$GIMP_CONFIG_DIR")"

        # Backup original config if it exists
        ORIG_CONFIG_BACKUP=""
        if [ -e "$GIMP_CONFIG_DIR" ]; then
          ORIG_CONFIG_BACKUP="$GIMP_CONFIG_DIR.backup.$$"
          echo "Temporarily backing up your original GIMP configuration..."
          mv "$GIMP_CONFIG_DIR" "$ORIG_CONFIG_BACKUP"
        fi

        # Create symlink to our managed config
        ln -sf "$PHOTOGIMP_CONFIG_DIR" "$GIMP_CONFIG_DIR"

        echo "Launching GIMP with PhotoGIMP customizations..."

        # Launch GIMP
        gimp "$@" &
        GIMP_PID=$!

        # Wait for GIMP to exit
        wait $GIMP_PID
        EXIT_CODE=$?

        # Restore original config if it exists
        if [ -n "$ORIG_CONFIG_BACKUP" ]; then
          echo "Restoring original GIMP configuration..."
          rm -f "$GIMP_CONFIG_DIR"
          mv "$ORIG_CONFIG_BACKUP" "$GIMP_CONFIG_DIR"
        fi

        exit $EXIT_CODE
      '';
    };

    # Create a custom package that combines GIMP with our wrapper
    photogimp = pkgs.symlinkJoin {
      name = "photogimp";
      paths = [
        gimp-wrapper
        pkgs.gimp
      ];
      postBuild = ''
        if [ -f $out/bin/gimp-bin ]; then
          # Some systems might have gimp-bin as the actual binary
          mv $out/bin/gimp $out/bin/gimp-original || true
          cp ${gimp-wrapper}/bin/gimp $out/bin/gimp
          chmod +x $out/bin/gimp
        fi
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

    # Create the app bundle
    createPhotoGimpApp = pkgs.runCommand "PhotoGIMP.app" {} ''
      mkdir -p $out/Applications/PhotoGIMP.app/Contents/{MacOS,Resources}

      # Create Info.plist
      cat > $out/Applications/PhotoGIMP.app/Contents/Info.plist << EOF
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>CFBundleExecutable</key>
        <string>PhotoGIMP</string>
        <key>CFBundleIconFile</key>
        <string>appIcon</string>
        <key>CFBundleIdentifier</key>
        <string>org.gimp.PhotoGIMP</string>
        <key>CFBundleName</key>
        <string>PhotoGIMP</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>CFBundleShortVersionString</key>
        <string>1.0</string>
        <key>LSMinimumSystemVersion</key>
        <string>10.10.0</string>
      </dict>
      </plist>
      EOF

      # Create launcher script
      cat > $out/Applications/PhotoGIMP.app/Contents/MacOS/PhotoGIMP << EOF
      #!/bin/bash
      exec ${photogimp}/bin/gimp "\$@"
      EOF
      chmod +x $out/Applications/PhotoGIMP.app/Contents/MacOS/PhotoGIMP

      # Copy icon
      cp ${photoGimpIcon}/icon.png $out/Applications/PhotoGIMP.app/Contents/Resources/appIcon.icns
    '';

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
        environment.systemPackages = [photogimp];
        system.activationScripts.postActivation.text = ''
          # Create a temporary script to handle installation
          INSTALL_SCRIPT=$(mktemp)
          chmod +x "$INSTALL_SCRIPT"

          cat > "$INSTALL_SCRIPT" << 'EOF'
          #!/bin/bash
          set -e
          # Remove existing PhotoGIMP.app if it exists
          /bin/rm -rf /Applications/PhotoGIMP.app
          # Install PhotoGIMP.app
          /bin/cp -rf ${createPhotoGimpApp}/Applications/PhotoGIMP.app /Applications/
          # Fix permissions
          /usr/sbin/chown -R "$(/usr/bin/whoami):staff" /Applications/PhotoGIMP.app
          EOF

          # Run the script with elevated privileges
          /usr/bin/osascript -e "do shell script \"$INSTALL_SCRIPT\" with administrator privileges"

          # Clean up
          rm -f "$INSTALL_SCRIPT"
        '';
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
        home.packages = [photogimp];
        home.activation.installPhotoGIMP = lib.hm.dag.entryAfter ["writeBoundary"] ''
          # Create a temporary script to handle installation
          INSTALL_SCRIPT=$(mktemp)
          chmod +x "$INSTALL_SCRIPT"

          cat > "$INSTALL_SCRIPT" << 'EOF'
          #!/bin/bash
          set -e
          # Remove existing PhotoGIMP.app if it exists
          /bin/rm -rf /Applications/PhotoGIMP.app
          # Install PhotoGIMP.app
          /bin/cp -rf ${createPhotoGimpApp}/Applications/PhotoGIMP.app /Applications/
          # Fix permissions
          /usr/sbin/chown -R "$(/usr/bin/whoami):staff" /Applications/PhotoGIMP.app
          EOF

          # Run the script with elevated privileges
          /usr/bin/osascript -e "do shell script \"$INSTALL_SCRIPT\" with administrator privileges"

          # Clean up
          rm -f "$INSTALL_SCRIPT"
        '';
      };
    };
  in {
    packages.${system} = {
      photogimp = photogimp;
      photoGimpApp = createPhotoGimpApp;
      default = createPhotoGimpApp;
    };

    nixosModules.default = darwinModule;
    darwinModules.default = darwinModule;
    homeManagerModules.default = homeManagerModule;
  };
}
