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
    gimp-wrapper = let
      configDir = "$HOME/.photogimp-config";
      gimpConfigDir = "$HOME/Library/Application Support/GIMP/2.10";
    in
      pkgs.stdenv.mkDerivation {
        name = "gimp-wrapper";
        buildInputs = [pkgs.makeWrapper];

        dontUnpack = true;

        installPhase = ''
          mkdir -p $out/bin $out/share/photogimp

          # Create the wrapper script
          makeWrapper ${pkgs.gimp}/bin/gimp $out/bin/gimp \
            --run "mkdir -p '${configDir}'" \
            --run "if [ ! -f '${configDir}/.photogimp_installed' ]; then cp -r ${photoGimpConfigSetup}/config/* '${configDir}/' 2>/dev/null || true; fi" \
            --run "mkdir -p '$(dirname ${gimpConfigDir})'" \
            --run "if [ -e '${gimpConfigDir}' ]; then mv '${gimpConfigDir}' '${gimpConfigDir}.backup.$$'; fi" \
            --run "ln -sf '${configDir}' '${gimpConfigDir}'" \
            --run "trap 'if [ -e \"${gimpConfigDir}.backup.$$\" ]; then rm -f \"${gimpConfigDir}\"; mv \"${gimpConfigDir}.backup.$$\" \"${gimpConfigDir}\"; fi' EXIT"
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
    createPhotoGimpApp = pkgs.stdenv.mkDerivation {
      name = "PhotoGIMP";

      buildInputs = [pkgs.makeWrapper];
      dontUnpack = true;

      installPhase = ''
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
        makeWrapper ${photogimp}/bin/gimp $out/Applications/PhotoGIMP.app/Contents/MacOS/PhotoGIMP

        # Copy icon
        cp ${photoGimpIcon}/icon.png $out/Applications/PhotoGIMP.app/Contents/Resources/appIcon.icns
      '';

      meta = {
        description = "PhotoGIMP.app bundle";
        platforms = pkgs.lib.platforms.darwin;
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
        environment.systemPackages = [photogimp];
        system.activationScripts.installPhotoGIMP = {
          text = ''
            echo "Installing PhotoGIMP.app..."
            sudo ${pkgs.rsync}/bin/rsync -a --delete "${createPhotoGimpApp}/Applications/PhotoGIMP.app/" "/Applications/PhotoGIMP.app/"
            sudo ${pkgs.coreutils}/bin/chown -R "$USER:staff" "/Applications/PhotoGIMP.app"
          '';
          deps = [];
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
        home.packages = [photogimp];
        home.activation.installPhotoGIMP = lib.hm.dag.entryAfter ["writeBoundary"] ''
          echo "Installing PhotoGIMP.app..."
          sudo ${pkgs.rsync}/bin/rsync -a --delete "${createPhotoGimpApp}/Applications/PhotoGIMP.app/" "/Applications/PhotoGIMP.app/"
          sudo ${pkgs.coreutils}/bin/chown -R "$USER:staff" "/Applications/PhotoGIMP.app"
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
