{pkgs, ...}: {
  imports = [
  ];

  config = {
    boot = {
      kernelModules = ["zfs"];
      loader.grub.zfsSupport = true;
      supportedFilesystems = ["zfs"];
      zfs = {
        forceImportRoot = false; # zfs_force=1 in kernel command line.
      };
    };
    services = {
      zfs = {
        autoScrub = {
          enable = true;
          interval = "*-*-* 04:00:00";
        };
        trim = {
          enable = true;
          interval = "*-*-* 05:00:00";
        };
        zed.settings = {
          ZED_DEBUG_LOG = "/tmp/zed.debug.log";
          ZED_EMAIL_ADDR = let at = "@"; in "bakhtiyarneyman+zed${at}gmail.com";
          ZED_EMAIL_PROG = "${pkgs.msmtp}/bin/msmtp";
          ZED_EMAIL_OPTS = "@ADDRESS@";
          ZED_LOCKDIR = "/var/lock";

          ZED_NOTIFY_INTERVAL_SECS = 3600;
          ZED_NOTIFY_VERBOSE = false;

          ZED_USE_ENCLOSURE_LEDS = true;
          ZED_SCRUB_AFTER_RESILVER = true;
        };
      };
      zrepl = {
        enable = true;
        settings = {
          global = {
            logging = [
              {
                type = "syslog";
                format = "human";
                level = "info";
              }
            ];
          };
        };
      };
    };
  };
}
