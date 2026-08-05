{...}: {
  config = {
    networking = {
      firewall.trustedInterfaces = ["tailscale0"];
      hosts = {
        "100.65.77.115" = ["iron-tailscale" "iron-initrd"];
        "100.126.205.61" = ["mercury-tailscale"];
      };
      networkmanager.dns = "systemd-resolved";
    };

    services = {
      # Keep each network link's public DNS while allowing Tailscale to install
      # split-DNS routes for the tailnet.
      resolved.enable = true;
      tailscale.enable = true;
    };
  };
}
