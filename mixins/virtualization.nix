{
  config = {
    programs.virt-manager.enable = true;
    users.users.bakhtiyar.extraGroups = [
      "docker"
      "libvirtd"
      "vboxusers"
    ];

    virtualisation = {
      docker.enable = true;
      libvirtd.enable = true;
      virtualbox.host.enable = true;
    };
  };
}
