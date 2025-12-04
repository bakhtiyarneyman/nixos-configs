{config, ...}: let
  canHibernate = builtins.elem "nohibernate" config.boot.kernelParams;
in {
  services = {
    logind.settings.Login = {
      HandleLidSwitch =
        if canHibernate
        then "suspend"
        else "suspend-then-hibernate";
      HandleLidSwitchExternalPower = "suspend";
    };

    # Powertop disables wired mice.
    tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
        PLATFORM_PROFILE_ON_BAT = "low_power";
        PCIE_ASPM_ON_BAT = "powersupersave";
      };
    };

    upower.enable = true;
  };
}
