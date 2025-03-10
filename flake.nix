{
  description = "PhotoGIMP customizations for GIMP on macOS - provides Photoshop-like UI and shortcuts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    mac-app-util.url = "github:hraban/mac-app-util";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    mac-app-util,
    flake-utils,
  }:
    flake-utils.lib.eachSystem ["aarch64-darwin" "x86_64-darwin"] (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      lib = pkgs.lib;

      # System-specific configuration
      systemConfig = {
        aarch64-darwin = {
          archName = "Apple Silicon";
          gimpBinary = "${pkgs.gimp}/bin/gimp";
        };
        x86_64-darwin = {
          archName = "Intel";
          gimpBinary = "${pkgs.gimp}/bin/gimp";
        };
      };

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

          # Check if we're running on the correct architecture
          if [ "$(uname -m)" = "arm64" ] && [ "${system}" != "aarch64-darwin" ]; then
            echo "Warning: You are running on Apple Silicon but using the Intel version"
          elif [ "$(uname -m)" = "x86_64" ] && [ "${system}" != "x86_64-darwin" ]; then
            echo "Warning: You are running on Intel but using the Apple Silicon version"
          fi

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
              --add-flags ${systemConfig.${system}.gimpBinary} \
              --set PATH ${lib.makeBinPath [pkgs.coreutils pkgs.bash]}
          '';

          meta = {
            description = "GIMP wrapper with PhotoGIMP configuration (${systemConfig.${system}.archName})";
            mainProgram = "gimp";
            platforms = [system];
          };
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
          description = "GIMP with PhotoGIMP configuration for a Photoshop-like experience (${systemConfig.${system}.archName})";
          longDescription = ''
            PhotoGIMP is a patch for GIMP 2.10+ that makes it more familiar to Adobe Photoshop users.
            Features include:
            - Tool organization mimicking Photoshop
            - Photoshop-like keyboard shortcuts for Windows
            - New Python filters installed by default
            - New splash screen
            - Maximized canvas space

            This version is built for ${systemConfig.${system}.archName} Macs.
          '';
          homepage = "https://github.com/Diolinux/PhotoGIMP";
          license = pkgs.lib.licenses.gpl3;
          platforms = [system];
          mainProgram = "gimp";
        };
      };

      # Create the app bundle
      createPhotoGimpApp = pkgs.stdenv.mkDerivation {
        name = "PhotoGIMP";
        version = "1.0";

        buildInputs = [
          pkgs.makeWrapper
          pkgs.imagemagick
          pkgs.libicns
        ];

        dontUnpack = true;

        installPhase = ''
          mkdir -p $out/Applications/PhotoGIMP.app/Contents/{MacOS,Resources}

          # Convert PNG to ICNS
          ${pkgs.imagemagick}/bin/convert ${photoGimpIcon}/icon.png -resize 512x512 icon.png
          ${pkgs.libicns}/bin/png2icns $out/Applications/PhotoGIMP.app/Contents/Resources/appIcon.icns icon.png

          # Create Info.plist with more macOS metadata
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
            <key>CFBundleVersion</key>
            <string>1.0</string>
            <key>LSApplicationCategoryType</key>
            <string>public.app-category.graphics-design</string>
            <key>NSHighResolutionCapable</key>
            <true/>
            <key>NSRequiresAquaSystemAppearance</key>
            <true/>
            <key>LSArchitecturePriority</key>
            <array>
              <string>${
            if system == "aarch64-darwin"
            then "arm64"
            else "x86_64"
          }</string>
            </array>
          </dict>
          </plist>
          EOF

          # Create launcher script
          makeWrapper ${photogimp}/bin/gimp $out/Applications/PhotoGIMP.app/Contents/MacOS/PhotoGIMP \
            --set PATH "${lib.makeBinPath [pkgs.gimp]}" \
            --set XDG_DATA_DIRS "${pkgs.gimp}/share"
        '';

        meta = {
          description = "PhotoGIMP.app bundle (${systemConfig.${system}.archName})";
          platforms = [system];
          homepage = "https://github.com/Diolinux/PhotoGIMP";
          license = pkgs.lib.licenses.gpl3;
        };
      };
    in {
      packages = {
        photogimp = photogimp;
        photoGimpApp = createPhotoGimpApp;
        default = createPhotoGimpApp;
      };
    })
    // {
      # Non-system specific outputs
      nixosModules.default = {
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
          environment.systemPackages = [self.packages.${pkgs.system}.photogimp];
          system.build.applications = pkgs.lib.mkForce (pkgs.buildEnv {
            name = "applications";
            paths = [self.packages.${pkgs.system}.photoGimpApp];
            pathsToLink = ["/Applications"];
          });
        };
      };

      darwinModules.default = self.nixosModules.default;

      homeManagerModules.default = {
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
          home.packages = [self.packages.${pkgs.system}.photogimp];
          home.activation.installPhotoGIMP = lib.hm.dag.entryAfter ["writeBoundary"] ''
            echo "Checking PhotoGIMP.app installation..."

            installApp() {
              echo "Installing PhotoGIMP.app..."
              /usr/bin/osascript -e "do shell script \"rm -rf /Applications/PhotoGIMP.app\" with administrator privileges"
              /usr/bin/osascript -e "do shell script \"cp -rf ${self.packages.${pkgs.system}.photoGimpApp}/Applications/PhotoGIMP.app /Applications/ && chown -R $USER:staff /Applications/PhotoGIMP.app\" with administrator privileges"
            }

            if [ ! -e "/Applications/PhotoGIMP.app" ]; then
              installApp
            else
              # Check if the app bundle is different
              if ! diff -qr "${self.packages.${pkgs.system}.photoGimpApp}/Applications/PhotoGIMP.app" "/Applications/PhotoGIMP.app" &>/dev/null; then
                echo "Updating PhotoGIMP.app..."
                installApp
              else
                echo "PhotoGIMP.app is up to date"
              fi
            fi
          '';
        };
      };
    };
}