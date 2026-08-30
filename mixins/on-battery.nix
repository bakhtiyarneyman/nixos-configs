{
  config,
  lib,
  pkgs,
  ...
}: let
  canHibernate = builtins.elem "nohibernate" config.boot.kernelParams;
in {
  services = {
    # Chrony's RTC tracking holds /dev/rtc0 exclusively, blocking rtcwake below.
    chrony.enableRTCTrimming = false;

    logind.settings.Login = {
      # Experiment: after resume, logind's default 30-second lid-switch holdoff
      # coincided with repeated PrepareForSleep cycles that re-ran swayidle's
      # before-sleep locker.  Disabling the holdoff tests that correlation while
      # retaining logind's normal lid-close actions.  It is not yet evidence that
      # the holdoff itself is the root cause.
      HoldoffTimeoutSec = 0;
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

  environment.systemPackages = lib.optionals config.services.displayManager.enable [
    pkgs.gnome-power-manager
  ];

  systemd.services.suspend-ac-check = {
    description = "Set RTC wake alarm on AC to detect power disconnect";
    before = ["systemd-suspend.service"];
    wantedBy = ["systemd-suspend.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "suspend-ac-check" ''
        if [ "$(cat /sys/class/power_supply/ACAD/online 2>/dev/null)" = "1" ]; then
          ${pkgs.util-linux}/bin/rtcwake -m no -s 600
        fi
      '';
    };
  };
}
