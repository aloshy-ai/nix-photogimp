# PhotoGIMP Nix Flake

A Nix flake that packages PhotoGIMP customizations for GIMP on macOS, providing a Photoshop-like experience with familiar UI and shortcuts.

[![](https://img.shields.io/badge/aloshy.🅰🅸-000000.svg?style=for-the-badge)](https://aloshy.ai)
[![Powered By Nix](https://img.shields.io/badge/NIX-POWERED-5277C3.svg?style=for-the-badge&logo=nixos)](https://nixos.org)
[![Platform](https://img.shields.io/badge/MACOS-ONLY-000000.svg?style=for-the-badge&logo=apple)](https://github.com/aloshy/nix-photogimp)
[![Build Status](https://img.shields.io/badge/BUILD-PASSING-success.svg?style=for-the-badge&logo=github)](https://github.com/aloshy/nix-photogimp/actions)
[![License](https://img.shields.io/badge/LICENSE-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

## Features

- Photoshop-like tool organization and interface
- Familiar keyboard shortcuts
- Pre-installed Python filters
- Custom splash screen
- Maximized canvas space
- Seamless integration with macOS
- Automatic configuration management
- Non-destructive installation (preserves original GIMP configuration)

## Prerequisites

- macOS (supports both Apple Silicon and Intel)
- Nix package manager with flakes enabled

## Installation

### Using nix-darwin

Add this flake to your `flake.nix`:

```nix
{
  inputs.nix-photogimp.url = "github:aloshy/nix-photogimp";
}
```

Then include it in your configuration:

```nix
{
  imports = [ 
    inputs.nix-photogimp.darwinModules.default
  ];
}
```

### Using home-manager

Add to your home-manager configuration:

```nix
{
  imports = [
    inputs.nix-photogimp.homeManagerModules.default
  ];
}
```

### Direct Installation

You can also install it directly using:

```bash
nix profile install github:aloshy/nix-photogimp
```

## Usage

After installation, you can find PhotoGIMP in your Applications folder as "PhotoGIMP.app". Launch it like any other macOS application.

The first time you run PhotoGIMP, it will automatically:
1. Back up your existing GIMP configuration (if any)
2. Set up the PhotoGIMP customizations
3. Restore your original configuration when you close GIMP

## Development

To build and test locally:

```bash
# Build the package
nix build

# Run tests
nix flake check
```

## Technical Details

The flake provides several outputs:

- `packages.photogimp`: The base PhotoGIMP package
- `packages.photoGimpApp`: The macOS application bundle
- `darwinModules.default`: NixOS Darwin module
- `homeManagerModules.default`: Home Manager module

## Acknowledgments

This project packages [PhotoGIMP by Diolinux](https://github.com/Diolinux/PhotoGIMP) for the Nix ecosystem.

## License

This project uses a dual-license structure:

- The Nix packaging code and configuration files are licensed under the [MIT License](LICENSE)

## Contributing

Contributions are welcome! Please follow these steps to contribute:

### Getting Started

1. Fork the repository
2. Create a new branch for your feature (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests locally to ensure everything works
5. Commit your changes (`git commit -m 'Add some amazing feature'`)
6. Push to your branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Development Guidelines

- Follow the existing code style and conventions
- Write clear, descriptive commit messages
- Add tests for new features when applicable
- Update documentation as needed
- Ensure all tests pass before submitting a PR

### Pull Request Process

1. Update the README.md with details of changes if applicable
2. Update the version numbers following [Semantic Versioning](https://semver.org/)
3. Your PR will be reviewed by maintainers
4. Once approved, your PR will be merged

### Code of Conduct

Please note that this project adheres to a Code of Conduct. By participating in this project, you agree to abide by its terms.

#### Our Standards

- Use welcoming and inclusive language
- Be respectful of differing viewpoints and experiences
- Accept constructive criticism gracefully
- Focus on what is best for the community
- Show empathy towards other community members

### Reporting Issues

- Use the GitHub issue tracker to report bugs
- Describe the bug in detail
- Include steps to reproduce the issue
- Specify your environment (OS, Nix version, etc.)
- Add relevant screenshots if applicable

### Questions or Suggestions?

Feel free to open an issue for any questions or suggestions you might have. We appreciate your feedback! 