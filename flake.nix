{
  description = "PhotoGIMP customizations for GIMP on macOS - provides Photoshop-like UI and shortcuts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils-plus.url = "github:gytis-ivaskevicius/flake-utils-plus";
    mac-app-util.url = "github:hraban/mac-app-util";
  };

  outputs = { self, nixpkgs, flake-utils-plus, mac-app-util }:
    let
      # Common configuration shared across systems
      photoGimpSrcInfo = {
        owner = "Diolinux";
        repo = "PhotoGIMP";
        rev = "1.0";
        sha256 = "0g076aa6jpmz4kxlwrw2zhbqirlj6y24vyl3g8jdl9qmkykm8z02";
      };
      
      # Helper function to get icon path for any system
      getPhotoGimpIconPath = system: let 
        pkgs = import nixpkgs { inherit system; };
        photoGimpSrc = pkgs.fetchFromGitHub photoGimpSrcInfo;
      in "${photoGimpSrc}/.local/share/icons/hicolor/256x256/apps/photogimp.png";
    in
    flake-utils-plus.lib.mkFlake {
      inherit self;
      
      systems = [ "aarch64-darwin" "x86_64-darwin" ];
      
      perSystem = { system, pkgs, ... }: 
        let
          photoGimpSrc = pkgs.fetchFromGitHub photoGimpSrcInfo;
          
          # Extract config files
          photoGimpConfig = pkgs.runCommand "photogimp-config" {} ''
            mkdir -p $out
            cp -r ${photoGimpSrc}/.var/app/org.gimp.GIMP/config/GIMP/2.10/* $out/
          '';
          
          # Get the icon
          photoGimpIcon = pkgs.runCommand "photogimp-icon" {} ''
            mkdir -p $out
            cp ${photoGimpSrc}/.local/share/icons/hicolor/256x256/apps/photogimp.png $out/icon.png
          '';
          
          # Create wrapper script
          gimp-wrapper = pkgs.writeShellApplication {
            name = "gimp";
            runtimeInputs = [ pkgs.gimp ];
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
                cp -r ${photoGimpConfig}/* "$PHOTOGIMP_CONFIG_DIR/" 2>/dev/null || true
                touch "$PHOTOGIMP_CONFIG_DIR/.photogimp_installed"
              fi
              
              # Create a temporary script that will clean up after GIMP exits
              CLEANUP_SCRIPT=$(mktemp)
              chmod +x "$CLEANUP_SCRIPT"
              
              cat > "$CLEANUP_SCRIPT" << 'EOF'
              #!/bin/bash
              set -e
              
              GIMP_CONFIG_DIR="$1"
              ORIG_CONFIG_BACKUP="$2"
              GIMP_PID="$3"
              
              # Wait for GIMP to exit
              wait "$GIMP_PID" 2>/dev/null || true
              
              echo "Restoring original GIMP configuration..."
              
              # Restore original config if it exists
              if [ -d "$ORIG_CONFIG_BACKUP" ]; then
                rm -rf "$GIMP_CONFIG_DIR" 2>/dev/null || true
                mv "$ORIG_CONFIG_BACKUP" "$GIMP_CONFIG_DIR"
              else
                # Just remove the symlink
                rm -f "$GIMP_CONFIG_DIR"
              fi
              
              # Remove this script
              rm -f "$0"
              EOF
              
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
              
              # Run cleanup script in background
              "$CLEANUP_SCRIPT" "$GIMP_CONFIG_DIR" "$ORIG_CONFIG_BACKUP" $GIMP_PID &
              
              # Wait for GIMP to exit
              wait $GIMP_PID
              exit $?
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
          createPhotoGimpApp = pkgs.runCommand "PhotoGIMP.app" {
            nativeBuildInputs = [ mac-app-util.packages.${system}.default ];
          } ''
            mkdir -p $out/Applications
            mktrampoline ${photogimp}/bin/gimp $out/Applications/PhotoGIMP.app
            cp ${photoGimpIcon}/icon.png $out/Applications/PhotoGIMP.app/Contents/Resources/appIcon.icns
          '';
          
        in {
          # Standard package output
          packages = {
            photogimp = photogimp;
            photoGimpApp = createPhotoGimpApp;
            default = createPhotoGimpApp;
          };
          
          # Checks
          checks = {
            build-test = self.packages.${system}.default;
            wrapper-test = pkgs.runCommand "photogimp-wrapper-test" {
              buildInputs = [ pkgs.bash ];
            } ''
              # Verify the wrapper script exists and is executable
              test -f ${gimp-wrapper}/bin/gimp
              test -x ${gimp-wrapper}/bin/gimp
              
              # Verify the icon exists
              test -f ${photoGimpIcon}/icon.png
              
              # Verify the config files exist
              test -d ${photoGimpConfig}
              
              # All tests passed
              touch $out
            '';
          };
        };

      # Darwin Module
      flakeModules.darwinModules.default = { pkgs, system, ... }: {
        imports = [ mac-app-util.darwinModules.default ];
        environment.systemPackages = [ 
          (pkgs.callPackage ({ pkgs }: self.packages.${system}.photogimp) {})
        ];
        system.activationScripts.postActivation.text = ''
          # Create PhotoGIMP app in /Applications
          ${mac-app-util.packages.${system}.default}/bin/mktrampoline ${self.packages.${system}.photogimp}/bin/gimp /Applications/PhotoGIMP.app
          cp ${getPhotoGimpIconPath system} /Applications/PhotoGIMP.app/Contents/Resources/appIcon.icns
        '';
      };

      # Home-manager Module
      flakeModules.homeManagerModules.default = { pkgs, system, ... }: {
        imports = [ mac-app-util.homeManagerModules.default ];
        home.packages = [ 
          (pkgs.callPackage ({ pkgs }: self.packages.${system}.photogimp) {})
        ];
        home.activation.createPhotoGimpApp = ''
          # Create PhotoGIMP app in ~/Applications
          $DRY_RUN_CMD mkdir -p ~/Applications
          $DRY_RUN_CMD ${mac-app-util.packages.${system}.default}/bin/mktrampoline ${self.packages.${system}.photogimp}/bin/gimp ~/Applications/PhotoGIMP.app
          $DRY_RUN_CMD cp ${getPhotoGimpIconPath system} ~/Applications/PhotoGIMP.app/Contents/Resources/appIcon.icns
        '';
      };
    };
}
