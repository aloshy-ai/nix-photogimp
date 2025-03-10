{
  description = "Inkustrator customizations for Inkscape on macOS - provides Illustrator-like UI and shortcuts";

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
          inkscapeBinary = "${pkgs.inkscape}/bin/inkscape";
        };
        x86_64-darwin = {
          archName = "Intel";
          inkscapeBinary = "${pkgs.inkscape}/bin/inkscape";
        };
      };

      inkustratorSrcInfo = {
        owner = "lucasgabmoreno";
        repo = "inkustrator";
        rev = "main";
        sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      };

      inkustratorSrc = pkgs.fetchFromGitHub inkustratorSrcInfo;

      # Create a derivation for the Inkustrator config
      inkustratorConfigSetup = pkgs.stdenv.mkDerivation {
        name = "inkustrator-config-setup";
        src = inkustratorSrc;

        installPhase = ''
          mkdir -p $out/config
          cp -r $src/config/* $out/config/
          touch $out/config/.inkustrator_installed
        '';
      };

      # Get the icon
      inkustratorIcon = pkgs.stdenv.mkDerivation {
        name = "inkustrator-icon";
        src = inkustratorSrc;

        installPhase = ''
          mkdir -p $out
          cp $src/icon/inkustrator.png $out/icon.png
        '';
      };

      # Create wrapper script
      inkscape-wrapper = let
        configDir = "$HOME/.inkustrator-config";
        inkscapeConfigDir = "$HOME/Library/Application Support/org.inkscape.Inkscape";

        # Create a script to handle config setup and cleanup
        configScript = pkgs.writeScript "inkustrator-config" ''
          #!${pkgs.bash}/bin/bash

          # Check if we're running on the correct architecture
          if [ "$(uname -m)" = "arm64" ] && [ "${system}" != "aarch64-darwin" ]; then
            echo "Warning: You are running on Apple Silicon but using the Intel version"
          elif [ "$(uname -m)" = "x86_64" ] && [ "${system}" != "x86_64-darwin" ]; then
            echo "Warning: You are running on Intel but using the Apple Silicon version"
          fi

          # Ensure config directories exist
          mkdir -p '${configDir}' "$(dirname '${inkscapeConfigDir}')"

          # Install Inkustrator config if needed
          if [ ! -f '${configDir}/.inkustrator_installed' ] || [ -z "$(ls -A '${configDir}')" ]; then
            echo "Setting up Inkustrator configuration..."
            rm -rf '${configDir}'/*
            cp -r ${inkustratorConfigSetup}/config/* '${configDir}/' 2>/dev/null || true
          fi

          # Backup and link config
          if [ -e '${inkscapeConfigDir}' ] && [ ! -L '${inkscapeConfigDir}' ]; then
            mv '${inkscapeConfigDir}' '${inkscapeConfigDir}.backup.$$'
          fi
          ln -sf '${configDir}' '${inkscapeConfigDir}'

          # Start Inkscape
          exec "$@"
        '';
      in
        pkgs.stdenv.mkDerivation {
          name = "inkscape-wrapper";
          buildInputs = [pkgs.makeWrapper];

          dontUnpack = true;

          installPhase = ''
            mkdir -p $out/bin $out/share/inkustrator
            makeWrapper ${configScript} $out/bin/inkscape \
              --add-flags ${systemConfig.${system}.inkscapeBinary} \
              --set PATH ${lib.makeBinPath [pkgs.coreutils pkgs.bash]}
          '';

          meta = {
            description = "Inkscape wrapper with Inkustrator configuration (${systemConfig.${system}.archName})";
            mainProgram = "inkscape";
            platforms = [system];
          };
        };

      # Create a custom package that combines Inkscape with our wrapper
      inkustrator = pkgs.symlinkJoin {
        name = "inkustrator";
        paths = [
          inkscape-wrapper
          pkgs.inkscape
        ];
        postBuild = ''
          if [ -f $out/bin/inkscape-bin ]; then
            mv $out/bin/inkscape $out/bin/inkscape-original || true
            cp ${inkscape-wrapper}/bin/inkscape $out/bin/inkscape
            chmod +x $out/bin/inkscape
          fi
        '';
        meta = {
          description = "Inkscape with Inkustrator configuration for an Illustrator-like experience (${systemConfig.${system}.archName})";
          longDescription = ''
            Inkustrator is a customization for Inkscape that makes it more familiar to Adobe Illustrator users.
            Features include:
            - Tool organization mimicking Illustrator
            - Illustrator-like keyboard shortcuts
            - Custom workspace layout
            - Enhanced productivity features

            This version is built for ${systemConfig.${system}.archName} Macs.
          '';
          homepage = "https://github.com/lucasgabmoreno/inkustrator";
          license = pkgs.lib.licenses.gpl3;
          platforms = [system];
          mainProgram = "inkscape";
        };
      };

      # Create the app bundle
      createInkustratorApp = pkgs.stdenv.mkDerivation {
        name = "Inkustrator";
        version = "1.0";

        buildInputs = [
          pkgs.makeWrapper
          pkgs.imagemagick
          pkgs.libicns
        ];

        dontUnpack = true;

        installPhase = ''
          mkdir -p $out/Applications/Inkustrator.app/Contents/{MacOS,Resources}

          # Convert PNG to ICNS
          ${pkgs.imagemagick}/bin/convert ${inkustratorIcon}/icon.png -resize 512x512 icon.png
          ${pkgs.libicns}/bin/png2icns $out/Applications/Inkustrator.app/Contents/Resources/appIcon.icns icon.png

          # Create Info.plist with more macOS metadata
          cat > $out/Applications/Inkustrator.app/Contents/Info.plist << EOF
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0">
          <dict>
            <key>CFBundleExecutable</key>
            <string>Inkustrator</string>
            <key>CFBundleIconFile</key>
            <string>appIcon</string>
            <key>CFBundleIdentifier</key>
            <string>org.inkscape.Inkustrator</string>
            <key>CFBundleName</key>
            <string>Inkustrator</string>
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
          makeWrapper ${inkustrator}/bin/inkscape $out/Applications/Inkustrator.app/Contents/MacOS/Inkustrator \
            --set PATH "${lib.makeBinPath [pkgs.inkscape]}" \
            --set XDG_DATA_DIRS "${pkgs.inkscape}/share"
        '';

        meta = {
          description = "Inkustrator.app bundle (${systemConfig.${system}.archName})";
          platforms = [system];
          homepage = "https://github.com/lucasgabmoreno/inkustrator";
          license = pkgs.lib.licenses.gpl3;
        };
      };
    in {
      packages = {
        inkustrator = inkustrator;
        inkustratorApp = createInkustratorApp;
        default = createInkustratorApp;
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
          programs.inkustrator = {
            enable = lib.mkEnableOption "Inkustrator";
          };
        };

        config = lib.mkIf config.programs.inkustrator.enable {
          environment.systemPackages = [self.packages.${pkgs.system}.inkustrator];
          system.build.applications = pkgs.lib.mkForce (pkgs.buildEnv {
            name = "applications";
            paths = [self.packages.${pkgs.system}.inkustratorApp];
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
          programs.inkustrator = {
            enable = lib.mkEnableOption "Inkustrator";
          };
        };

        config = lib.mkIf config.programs.inkustrator.enable {
          home.packages = [self.packages.${pkgs.system}.inkustrator];
          home.activation.installInkustrator = lib.hm.dag.entryAfter ["writeBoundary"] ''
            echo "Checking Inkustrator.app installation..."

            installApp() {
              echo "Installing Inkustrator.app..."
              /usr/bin/osascript -e "do shell script \"rm -rf /Applications/Inkustrator.app\" with administrator privileges"
              /usr/bin/osascript -e "do shell script \"cp -rf ${self.packages.${pkgs.system}.inkustratorApp}/Applications/Inkustrator.app /Applications/ && chown -R $USER:staff /Applications/Inkustrator.app\" with administrator privileges"
            }

            if [ ! -e "/Applications/Inkustrator.app" ]; then
              installApp
            else
              # Check if the app bundle is different
              if ! diff -qr "${self.packages.${pkgs.system}.inkustratorApp}/Applications/Inkustrator.app" "/Applications/Inkustrator.app" &>/dev/null; then
                echo "Updating Inkustrator.app..."
                installApp
              else
                echo "Inkustrator.app is up to date"
              fi
            fi
          '';
        };
      };
    };
}
