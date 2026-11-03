{
  pkgs,
  lib,
  ...
}: let
  # Shpool design constraints:
  # - The daemon and Fish integration work on headless and GUI machines alike.
  # - Alacritty automatically starts a shpool session.
  # - Closing a local window terminates its attached session and processes.
  # - Ctrl+Shift+Q preserves the session and returns to a shell for reattachment.
  # - Over SSH, the shortcut must detach the remote session, even from a local
  #   shpool session; loss of the SSH connection must never kill that session.
  # - Ctrl+D / exit closes an auto-started session and window without creating
  #   another session or leaving an extra shell.
  # - Completion describes sessions by host, directory, and latest/running command.
  # - Use stock shpool; load scripts and configuration only from the Nix store.
  # - Keep the feature small and independently revertible.
  # 0.11.5 restores mouse/input modes on reattach, so Codex can keep scrolling
  # its conversation above a fixed prompt in a new terminal. Use the unpatched
  # upstream release until our pinned nixpkgs supplies shpool >= 0.11.5;
  # then remove this override and use pkgs.shpool again.
  shpool = pkgs.shpool.overrideAttrs (final: _: {
    version = "0.11.5";
    src = pkgs.fetchFromGitHub {
      owner = "shell-pool";
      repo = "shpool";
      rev = "v${final.version}";
      hash = "sha256-AfuAGYgeGdbCTj0RA52xkxQ8ycrSXOnRJqRVTy85Buc=";
    };
    cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
      inherit (final) src pname version;
      hash = "sha256-K27VE9IBvldouiYr0RjUn2aqkVJjPF/FipBNsG5Nba8=";
    };
  });
  integration = pkgs.callPackage ../pkgs/shpool-integration.nix {inherit shpool;};
  sessionEnvironment = import ../lib/session-environment.nix;
in {
  # All CLI attachments use the wrapper; the daemon below uses stock shpool.
  environment.systemPackages = [integration];
  programs.fish.interactiveShellInit = ''
    source ${integration}/share/fish/shpool.fish
  '';

  environment.etc = {
    # The daemon clears its environment for each shell. Sway's systemd import
    # configures services, not these shells; NixOS shell init supplies static
    # settings. Forward only the additional per-connection values below.
    # The daemon watches the symlink-resolved path for reloads; a copy
    # (via mode) changes in place, while a store symlink target never does.
    "shpool/config.toml".mode = "0444";
    "shpool/config.toml".source = (pkgs.formats.toml {}).generate "shpool.toml" {
      # Blank disables prompt injection, which waits ~10s for fish to start.
      prompt_prefix = "";
      # Stock shpool already carries TERM, DISPLAY, LANG and SSH_AUTH_SOCK,
      # and supplies XDG_RUNTIME_DIR. Reuse SSH's terminal/notification context
      # and the desktop import's display context, excluding login-seat/VT IDs.
      forward_env =
        sessionEnvironment.ssh
        ++ lib.remove "DISPLAY" sessionEnvironment.desktop
        ++ [
          "SHPOOL_CLIENT_ID" # Daemon-written attachment receipt for safe close cleanup.
          "DBUS_SESSION_BUS_ADDRESS" # Reach the attaching user's session bus.
          "DESKTOP_SESSION" # Desktop-session name used by older applications.
          "GDK_PIXBUF_MODULE_FILE" # Locate the attaching desktop's image loaders.
          "I3SOCK" # Connect i3-compatible clients to the attaching compositor.
          "XCURSOR_SIZE" # Preserve the attaching desktop's cursor size.
          "XCURSOR_THEME" # Preserve the attaching desktop's cursor theme.
        ];
    };
  };

  # Socket-activated by the first attach; never restart away running sessions.
  systemd.packages = [shpool];
  systemd.user.sockets.shpool.wantedBy = ["sockets.target"];
  systemd.user.services.shpool.restartIfChanged = false;
}
