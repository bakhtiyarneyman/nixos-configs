# Per-connection values shared by environment forwarding boundaries.
# Static settings belong in environment.sessionVariables instead.
{
  ssh = [
    "COLORTERM" # Preserve truecolor support beyond TERM's terminal type.
    "CLAUDE_NOTIFY_SOCKET" # Route notifications through the SSH-forwarded socket.
    "CLAUDE_NOTIFY_WINDOW_PID" # Identify the originating window on that desktop.
  ];
  desktop = [
    "DISPLAY" # Connect X11 clients to the current display.
    "WAYLAND_DISPLAY" # Connect Wayland clients to the current display.
    "SWAYSOCK" # Let swaymsg address the current compositor.
    "XDG_CURRENT_DESKTOP" # Select desktop-specific portals and toolkit behavior.
    "XDG_SESSION_DESKTOP" # Identify the selected desktop session to applications.
    "XDG_SESSION_TYPE" # Let applications distinguish Wayland from X11.
  ];
}
