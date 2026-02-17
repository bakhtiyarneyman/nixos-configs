# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
sudo nixos-rebuild switch --flake /etc/nixos

# Build and switch for specific machine
sudo nixos-rebuild switch --flake /etc/nixos#iron

# Build without switching (test configuration)
sudo nixos-rebuild build --flake /etc/nixos#iron

# Update flake inputs
nix flake update

# Update specific input
nix flake lock --update-input nixpkgs
```

### Testing and Validation
```bash
# Check flake syntax and evaluate
nix flake check

# Show flake outputs
nix flake show

# Dry-run rebuild to see what would change
sudo nixos-rebuild dry-run --flake /etc/nixos
```

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
4. **Testing Changes**: Use `nixos-rebuild build` first, then `switch` after verification

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

## Development Memories
- Do not remove temporary debugging facilities until proven working.
- Use pkexec to execute privileged commands.
- When authentication prompts (pkexec, sudo) fail or get cancelled, ask the user before trying alternative commands.
- When pkexec fails restart soteria user service with `systemctl --user restart polkit-soteria.service`.
- Use exec to record debug messages in bash scripts.
- Never invoke `nixos-rebuild (boot|switch)` before testing the configuration with `nixos-rebuild test`.
- Never read files with passwords, stat them
- When claude is used via ssh, `sudo` must be used instead of `pkexec`.
- Don't build if you can just test
- Don't declare success until you have tested the configuration. It's not enough that `nixos-rebuild test` runs successfully, you might need to look into journal.
- Modules are global for all machines, machines import mixins directly.

## Communication

- If I'm asking a question, answer it instead of interpreting it as a request. I will use imperative mood for requests.
