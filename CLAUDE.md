# CLAUDE.md

## Repository Overview

This is a NixOS flake configuration repository for managing multiple machines with shared configurations. The repository uses a modular architecture with machine-specific configurations and reusable mixins.


## Architecture

### Core Structure
- **flake.nix**: Main flake entry point defining inputs, outputs, and system configurations
- **machines/**: Machine-specific configurations (iron.nix, mercury.nix, tin.nix, tungsten.nix)
- **mixins/**: Reusable configuration modules that can be imported by machines
- **modules/**: Custom NixOS modules for specific functionality
- **pkgs/**: Custom package definitions and overlays

### Key Components

**Machine Configuration Flow:**
1. `flake.nix` defines the system using `nixpkgs.lib.nixosSystem`
2. Each machine imports `mixins/core.nix` (base configuration)
3. Machine-specific file (e.g., `machines/iron.nix`) defines hardware and specialized services
4. Mixins provide feature sets (gui, bare-metal, virtualization, etc.)

**Mixins System:**
- `core.nix`: Base system configuration, users, packages, networking
- `gui.nix`: Desktop environment with Sway/i3, Wayland, GUI applications
- `bare-metal.nix`: Physical hardware optimizations, boot configuration
- `virtualization.nix`: VM and container support
- `trusted.nix`/`untrusted.nix`: Security boundary configurations

## Common Development Commands

### Building and Switching
```bash
# Build and switch to new configuration for current machine
pkexec nixos-rebuild switch --flake /etc/nixos

# Build and switch for specific machine
pkexec nixos-rebuild switch --flake /etc/nixos#iron

# Build without switching (test configuration)
pkexec nixos-rebuild build --flake /etc/nixos#iron

# Update flake inputs
nix flake update

# Update specific input
nix flake update nixpkgs
```

### Testing and Validation
```bash
# Check flake syntax and evaluate
nix flake check

# Show flake outputs
nix flake show

# Dry-run rebuild to see what would change
pkexec nixos-rebuild dry-run --flake /etc/nixos
```

### Building Custom Packages
```bash
# Build a custom package (e.g., claude-permission-hook)
nix-build -E '(import (builtins.getFlake "nixpkgs") { system = "x86_64-linux"; }).callPackage ./pkgs/claude-permission-hook.nix {}'
```
`cabal build` does not work on NixOS — C libraries (e.g., pcre) and pkg-config are not in global paths. Always use `nix-build` via `callPackage` for packages in `pkgs/`.

### Formatting and Linting
```bash
# Format Nix files with alejandra
alejandra .

# Check Nix syntax
nix-instantiate --parse-only file.nix
```

## Development Workflow

1. **Adding New Machines**: Create new file in `machines/` following existing pattern, update `machineNames` in `flake.nix`
2. **Custom Packages**: Add to `pkgs/` directory and reference in overlays section of `mixins/core.nix`
3. **Shared Configuration**: Add reusable features to `mixins/`, machine-specific config to `machines/`
4. **Testing Changes**: Use `nixos-rebuild test` first, then `switch` after verification

## Key Configuration Patterns

- **Secrets**: Stored in `secrets/` directory, referenced with absolute paths
- **SSH Keys**: Yubikey public keys defined in `flake.nix` specialArgs
- **ZFS Configuration**: Managed through `mixins/zfs.nix` with dataset definitions in machine configs
- **Networking**: Tailscale integration, machine-specific firewall rules
- **Home Assistant**: Custom packages in `pkgs/home-assistant/`

## Machine Roles
- **iron**: Main desktop/workstation with GUI, AMD GPU, ZFS, virtualization
- **tin**: Server/cache with media services, AI/ML workloads
- **mercury**: Laptop configuration with battery optimizations
- **tungsten**: Remote backup server

## Important Notes
- Configurations use `mutableUsers = false` - user management through Nix only
- Custom fish shell configuration with plugins in `pkgs/fish/`
- Email notifications configured via msmtp for system monitoring
- Auto-updates enabled with cache building strategy (iron builds first, others use cache)

## Permission Hook Security Invariants
- **xargs safety probe**: The xargs rule appends `--unrecognized-flag-injected-by-xargs-rule` to the subcommand before recursing. This probes whether the rule tree allows the command regardless of arguments (since xargs injects unknown arguments from stdin). Security depends on: (a) principle #2 is maintained — rules only whitelist explicitly enumerated flags, never catch-all `.*` patterns; (b) unconditionally-allowed programs (e.g. `grep ~> allow`) are genuinely safe with any arguments; (c) rules with argument whitelists never include the probe flag. See principle #10 in `Rules.hs` for full analysis.

## Development Memories
- Never invoke `nixos-rebuild (boot|switch)` before testing the configuration with `nixos-rebuild test`.
- Don't build or `nix flake check` if you can just test
- Don't declare success until you have tested the configuration. It's not enough that `nixos-rebuild test` runs successfully, you might need to look into journal.
- Modules are global for all machines, machines import mixins directly.
- On NixOS, binaries are not in standard paths. Always use `/usr/bin/env` for shebangs and absolute paths for referencing scripts/binaries.
- On GUI machines, use `pkexec nixos-rebuild ...`. Over SSH, use `sudo nixos-rebuild ...`.
