{
  config,
  lib,
  utils,
  ...
}:
# Assumptions about the system:
# - Has a TPM 2.0 device.
# - Has a LUKS device formatted as ext4. On it raw key files.
#   - Can be generated with `dd if=/dev/urandom bs=32 count=1 of=/mnt/secrets/zfs.key`.
let
  cfg = config.boot.autoUnlock;
  luksDevice = "auto-unlock-keys";
  mountPoint = "/" + luksDevice;
in
  with lib; {
    options.boot.autoUnlock = {
      enable = mkEnableOption "Enable TPM2-based automatic decryption of ZFS datasets";
      keys = {
        pool = mkOption {
          type = with types; str;
          example = "system";
          description = "The name of the encrypted ZFS pool";
        };
        partition = mkOption {
          # TODO: waiting for N devices out of a list.
          type = with types; str;
          example = "/dev/disk/by-id/foo-part3";
          description = "The names of the partition backing the encrypted pool";
        };
        blockDevice = mkOption {
          type = with types; str;
          example = "/dev/zvol/system/keys";
          description = "The name of the LUKS device";
        };
        files = mkOption {
          type = with types; attrsOf str;
          example = {"system/secrets" = "zfs.key";};
          description = "Path to the raw key the keys filesystem for each encryption root";
        };
      };
    };

    config = lib.mkIf cfg.enable {
      boot = {
        initrd = {
          kernelModules = ["tpm_crb"];
          availableKernelModules = ["ext4"];
          luks.devices."${luksDevice}" = {
            device = cfg.keys.blockDevice;
            crypttabExtraOpts = [
              "tpm2-device=auto"
              "tpm2-measure-pcr=yes"
            ];
          };
          systemd = {
            enable = true;
            contents = {
              "/etc/fstab".text = ''
                /dev/mapper/${luksDevice} ${mountPoint} ext4 defaults,nofail,x-systemd.device-timeout=0,ro 0 2
              '';
            };
            services = {
              "zfs-import-${cfg.keys.pool}".enable = false;

              import-auto-unlock-key-pool = let
                device = "${utils.escapeSystemdPath cfg.keys.partition}.device";
              in {
                requiredBy = ["load-system-key.service"];
                after = [device];
                bindsTo = [device];
                unitConfig.DefaultDependencies = false;
                serviceConfig = {
                  Type = "oneshot";
                  ExecStart = "${config.boot.zfs.package}/bin/zpool import -f -N -d /dev/disk/by-id ${cfg.keys.pool}";
                  RemainAfterExit = true;
                };
              };

              load-system-key = {
                wantedBy = ["sysroot.mount"];
                before = ["sysroot.mount"];
                unitConfig = {
                  RequiresMountsFor = [mountPoint];
                  DefaultDependencies = false;
                };
                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  ExecStart = let
                    loadKey = dataset: key: "${config.boot.zfs.package}/bin/zfs load-key -L file://${mountPoint}/${key} ${dataset}";
                  in
                    builtins.attrValues (builtins.mapAttrs loadKey cfg.keys.files);
                };
              };
            };
          };
        };
      };
    };
  }
