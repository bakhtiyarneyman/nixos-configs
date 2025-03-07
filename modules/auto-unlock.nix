{
  config,
  lib,
  utils,
  ...
}:
# Assumptions about the system.
# - Has a TPM 2.0 device. (`bootctl status`)
# - Secure boot is properly configured.
#   - NOTE: This probably requires imaging NixOS with a minimal installation, and only then switching to this repo, because I have not tested running `sbctl` from the installer image. Nevertheless, `sbctl` accepts --database-path /mnt/etc/secureboot` flag to redirect to the directory, so might work.
#   - Instructions:
#     - Set BIOS password.
#     - Run `sbctl create-keys --database-path=/etc/secureboot`.
#     - (When installing) Do a `nixos-install`.
#     - Run `sbctl verify`.
#       - When installing do `sbctl verify (fd '.efi' /mnt/boot)`.
#         - `--database-path` is not supported for `verify`. So probably won't work.
#     - Reboot into BIOS, enable Secure Boot, and then exit via `Reset to Setup Mode`
#     - Run `sbctl enroll-keys --microsoft`. Verify that the keys are in the UEFI firmware.
#     - Reboot and verify via `bootctl status` that Secure Boot is enabled.
# - Has a LUKS device formatted as ext4. On it raw key files.
#   - Can be generated with `dd if=/dev/urandom bs=32 count=1 of=/mnt/secrets/zfs.key`.
let
  cfg = config.boot.initrd.autoUnlock;
  luksDevice = "auto-unlock-keys";
  mountPoint = "/" + luksDevice;
in
  with lib; {
    options.boot.initrd.autoUnlock = {
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
          systemd = let
            zfs = config.boot.zfs.package;
          in {
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
                  ExecStart = "${zfs}/bin/zpool import -f -N -d /dev/disk/by-id ${cfg.keys.pool}";
                  RemainAfterExit = true;
                };
              };

              load-system-key = {
                requiredBy = ["sysroot.mount"];
                before = ["sysroot.mount"];
                unitConfig = {
                  RequiresMountsFor = [mountPoint];
                  DefaultDependencies = false;
                };
                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  ExecStart = let
                    # `-a` flag doesn't work with key location supplied via `-L`, so we iterate over all datasets.
                    loadKey = dataset: key: "${zfs}/bin/zfs load-key -L file://${mountPoint}/${key} ${dataset}";
                  in
                    # Load the keys for all datasets.
                    builtins.attrValues (builtins.mapAttrs loadKey cfg.keys.files)
                    # Ensure that the key volume can't be mounted again.
                    ++ [
                      "/bin/umount -l ${mountPoint}"
                      "${config.boot.initrd.systemd.package}/bin/systemd-cryptsetup detach ${luksDevice}"
                    ];
                };
              };
            };
          };
        };

        # Necessary, because PCR 15 will remain blank unless secure boot is enabled.
        lanzaboote = {
          enable = true;
          # Had to go to `pkgs.sbctl` source to find this. See assumptions above.
          pkiBundle = "/etc/secureboot";
        };
      };
    };
  }
