{
  config,
  lib,
  pkgs,
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
          description = "The name of the ZFS pool with the key for all datasets. Datasets on it will be unlocked automatically.";
        };
        blockDevice = mkOption {
          type = with types; str;
          example = "/dev/zvol/system/keys";
          description = "The name of the LUKS device";
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
            zfsCfg = config.boot.zfs;
            zfs = zfsCfg.package;
            datasetToPool = x: lib.elemAt (lib.splitString "/" x) 0;
            fsToPool = fs: datasetToPool fs.device;
            zfsFilesystems = lib.filter (x: x.fsType == "zfs") config.system.build.fileSystems;
            allPools = lib.unique ((map fsToPool zfsFilesystems) ++ zfsCfg.extraPools);
            delayImport = pool: {
              name = "zfs-import-${pool}";
              value = {
                unitConfig.RequiresMountsFor = [mountPoint];
              };
            };
          in {
            enable = true;
            contents = {
              "/etc/fstab".text = ''
                /dev/mapper/${luksDevice} ${mountPoint} ext4 defaults,nofail,x-systemd.device-timeout=0,ro 0 2
              '';
            };
            services =
              builtins.listToAttrs (map delayImport allPools)
              // {
                import-auto-unlock-key-pool = let
                  # TODO: waiting for N devices out of a list.
                  pool = cfg.keys.pool;
                  zpoolCmd = "${zfs}/sbin/zpool";
                  awkCmd = "${pkgs.gawk}/bin/awk";
                  devNodes = "/dev/disk/by-id";
                  timeoutSecs = 5;
                in {
                  requiredBy = ["zfs-import-${pool}.service"];
                  before = ["zfs-import-${pool}.service"];
                  unitConfig.DefaultDependencies = false;
                  serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                  };
                  script = ''
                    poolReady() {
                      state="$("${zpoolCmd}" import -d "${devNodes}" 2>/dev/null | "${awkCmd}" "/pool: ${pool}/ { found = 1 }; /state:/ { if (found == 1) { print \$2; exit } }; END { if (found == 0) { print \"MISSING\" } }")"
                      if [[ "$state" = "ONLINE" ]]; then
                        return 0
                      else
                        echo "Pool ${pool} in state $state, waiting"
                        return 1
                      fi
                    }
                    poolImported() {
                      "${zpoolCmd}" list ${pool} >/dev/null 2>/dev/null
                    }
                    poolImport() {
                      # shellcheck disable=SC2086
                      "${zpoolCmd}" import -d "${devNodes}" -N -f ${pool}
                    }

                    if ! poolImported; then
                      echo -n "importing ZFS pool \"${pool}\"..."
                      # Loop across the import until it succeeds, because the devices needed may not be discovered yet.
                      for _ in $(seq 1 ${toString timeoutSecs}); do
                        poolReady && poolImport && break
                        sleep 1
                      done
                      poolImported || poolImport  # Try one last time, e.g. to import a degraded pool.
                    fi
                  '';
                };

                # Ensure that the key volume can't be mounted again.
                relock-auto-unlock-key-pool = {
                  after = ["zfs-import.target"];
                  before = ["sysroot.mount"];
                  requiredBy = ["sysroot.mount"];
                  unitConfig = {
                    DefaultDependencies = false;
                  };
                  serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                    ExecStart = [
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
