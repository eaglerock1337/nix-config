{ config, lib, pkgs, operatorPubkeys, ... }:

# Initrd RAID-fallback rescue shell (dropbear SSH in initrd).
#
# When the mdadm RAID-1 array fails to assemble (e.g. USB drives missing or
# degraded beyond auto-recovery), the provisioned initrd would otherwise hang
# waiting for root — invisible on a headless node. This module starts a
# dropbear SSH server in the initrd with a static IP so the operator can SSH
# in from gibson to diagnose and manually recover.
#
# Normal boot path: RAID assembles, dropbear is torn down, stage 2 proceeds
# with DHCP networking as usual (flushBeforeStage2 = true).
#
# Rescue path: RAID absent after 60s → initrd prints banner → operator SSHes
# in → runs hlc-recover commands → exits shell → boot continues.
# If unrecoverable, operator runs `hlc-recover sd-boot` to revert to SD
# bootstrap, then reprovisions from the workstation.

let
  rescueInterface =
    if config.hlc.piFamily == "rpi5" then "end0" else "eth0";
  hostname = config.networking.hostName;
  rescueIp = config.hlc.rescueIp;

  recoverScript = import ./hlc-recover-script.nix { inherit hostname; };
in {
  options.hlc.rescueIp = lib.mkOption {
    type = lib.types.str;
    description = "Static IP for initrd rescue SSH (should match node's DHCP reservation)";
    example = "10.23.50.51";
  };

  config = {
    # mdadm tools in initrd for RAID assembly + manual recovery
    boot.swraid.enable = true;
    boot.swraid.mdadmConf = "MAILADDR root";

    # DR-001: filesystem + partition tools in initrd so the rescue shell can
    # actually format, fsck, and partition drives when disko fails mid-provision.
    # Without these, a failed provision leaves the operator unable to recover
    # without reflashing the SD card.
    #
    # DR-002: hlc-recover script provides guided recovery (status, mount, wipe,
    # sd-boot) so the operator doesn't need to remember raw mdadm/wipefs commands.
    boot.initrd.extraUtilsCommands = ''
      # ext4 (RAID root filesystem)
      # mke2fs is the real binary behind mkfs.ext4; e2fsck behind fsck.ext4.
      # NixOS initrd symlinks the fsck.*/mkfs.* names automatically — copying
      # both the real binary AND the symlink alias causes "File exists" at link time.
      copy_bin_and_libs ${pkgs.e2fsprogs}/bin/mke2fs
      copy_bin_and_libs ${pkgs.e2fsprogs}/bin/e2fsck
      # xfs (NVMe /srv on Pi 5)
      copy_bin_and_libs ${pkgs.xfsprogs}/bin/mkfs.xfs
      copy_bin_and_libs ${pkgs.xfsprogs}/bin/xfs_repair
      # partition + block device tools
      copy_bin_and_libs ${pkgs.gptfdisk}/bin/sgdisk
      copy_bin_and_libs ${pkgs.util-linux}/bin/blkid
      copy_bin_and_libs ${pkgs.util-linux}/bin/wipefs
      # nixos-anywhere requires setsid --wait for remote provisioning
      copy_bin_and_libs ${pkgs.util-linux}/bin/setsid

      # hlc-recover: guided recovery script
      cat > $out/bin/hlc-recover << 'RECOVERYEOF'
      ${recoverScript}
      RECOVERYEOF
      chmod +x $out/bin/hlc-recover
    '';

    # Drivers needed before stage 2
    boot.initrd.availableKernelModules = [
      "genet"         # bcmgenet NIC (Pi 4 and Pi 5)
      "md_mod"        # mdadm core
      "raid1"         # RAID-1 personality
      "usb_storage"   # USB mass storage (for RAID drives)
      "xhci_hcd"      # USB 3.0 host controller
      "vfat"          # FAT32 firmware partition mount (recovery)
      "fat"           # FAT core module (dep of vfat)
      "nls_cp437"     # codepage for FAT filenames
      "nls_iso8859_1" # codepage for FAT filenames
    ];

    # Static IP via kernel ip= parameter; parsed by initrd networking
    boot.kernelParams = [
      "ip=${rescueIp}::10.23.50.1:255.255.255.0:${hostname}:${rescueInterface}:none"
    ];

    boot.initrd.network = {
      enable = true;
      # Drop initrd network config before stage 2 so DHCP takes over cleanly
      flushBeforeStage2 = true;

      ssh = {
        enable = true;
        port = 22;
        hostKeys = [ ../../../../secrets/initrd/ssh_host_ed25519_key ];
        authorizedKeys = operatorPubkeys;
      };
    };

    # After device assembly: poll for RAID, print rescue banner if absent.
    # Dropbear is already running at this point — operator can SSH in regardless.
    boot.initrd.postDeviceCommands = lib.mkAfter ''
      echo "[raid-fallback] Checking for /dev/md/usb-raid..."
      waited=0
      timeout=60
      while [ "$waited" -lt "$timeout" ]; do
        if [ -e /dev/md/usb-raid ]; then
          echo "[raid-fallback] RAID array assembled after ''${waited}s — continuing boot"
          break
        fi
        sleep 2
        waited=$((waited + 2))
      done

      if ! [ -e /dev/md/usb-raid ]; then
        echo ""
        echo "=========================================="
        echo "  HLC INITRD RESCUE — ${hostname}"
        echo "=========================================="
        echo "  RAID array /dev/md/usb-raid NOT FOUND"
        echo "  SSH rescue: ssh root@${rescueIp}"
        echo ""
        echo "  Recovery tool:"
        echo "    hlc-recover              (show help)"
        echo "    hlc-recover status       (disk/RAID state)"
        echo "    hlc-recover wipe         (clean USB for reprovision)"
        echo "    hlc-recover sd-boot      (restore SD bootstrap boot)"
        echo "=========================================="
        echo ""
      fi
    '';
  };
}
