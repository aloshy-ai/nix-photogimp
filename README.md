# nix-inkustrator

A Nix package that provides Inkustrator customizations for Inkscape on macOS, making it more familiar to Adobe Illustrator users.

## Features

- Installs and configures Inkscape with Inkustrator customizations
- Provides an Illustrator-like interface and keyboard shortcuts
- Creates a proper macOS application bundle
- Supports both Apple Silicon and Intel Macs
- Integrates with Nix, NixOS, and nix-darwin

## Installation

### Using nix-darwin

Add the following to your `flake.nix`:

```nix
{
  inputs = {
    nix-inkustrator.url = "github:aloshy-ai/nix-inkustrator";
  };

  outputs = { self, darwin, nix-inkustrator, ... }: {
    darwinConfigurations."your-hostname" = darwin.lib.darwinSystem {
      modules = [
        nix-inkustrator.darwinModules.default
        {
          programs.inkustrator.enable = true;
        }
      ];
    };
  };
}
```

### Using Home Manager

Add the following to your Home Manager configuration:

```nix
{
  inputs = {
    nix-inkustrator.url = "github:aloshy-ai/nix-inkustrator";
  };

  outputs = { self, home-manager, nix-inkustrator, ... }: {
    homeConfigurations."your-username" = home-manager.lib.homeManagerConfiguration {
      modules = [
        nix-inkustrator.homeManagerModules.default
        {
          programs.inkustrator.enable = true;
        }
      ];
    };
  };
}
```

### Direct Installation

You can also install it directly using:

```bash
nix profile install github:aloshy-ai/nix-inkustrator
```

## Usage

After installation:

1. Launch Inkustrator from your Applications folder
2. The interface will be customized to match Adobe Illustrator's layout
3. Keyboard shortcuts will match Illustrator's defaults
4. Your settings will be preserved between updates

## Credits

- Original Inkustrator project by [Lucas Gabriel Moreno](https://github.com/lucasgabmoreno/inkustrator)
- Nix packaging by [aloshy-ai](https://github.com/aloshy-ai)

## License

This project is licensed under the GPL-3.0 License - see the original [Inkustrator repository](https://github.com/lucasgabmoreno/inkustrator) for details. 