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

  # hlc-recover: initrd recovery tool for HLC cluster nodes.
  # Written as an ash script — the initrd shell is busybox, not bash.
  # Build-time interpolation injects hostname for banner messages.
  recoverScript = ''
    #!/bin/sh
    # hlc-recover: initrd recovery tool for HLC cluster nodes
    # Available in the dropbear rescue shell when RAID fails to assemble.

    HOSTNAME="${hostname}"
    FIRMWARE_DEV=/dev/mmcblk0p1
    BOOTSTRAP_DEV=/dev/mmcblk0p2
    RAID_DEV=/dev/md/usb-raid
    BACKUP_NAME=.bootstrap-backup.tar.gz
    FW_MNT=/tmp/hlc-firmware
    BOOT_MNT=/tmp/hlc-bootstrap
    RAID_MNT=/tmp/hlc-raid

    usage() {
      echo "hlc-recover — initrd recovery tool for $HOSTNAME"
      echo ""
      echo "Commands:"
      echo "  status      Show RAID, disk, and mount state"
      echo "  mount       Assemble RAID and mount root for inspection"
      echo "  umount      Unmount RAID root"
      echo "  wipe [-y]   Stop RAID, wipe USB superblocks (prepares for reprovision)"
      echo "  sd-boot     Restore SD card bootstrap boot files"
      echo ""
      echo "Typical recovery flow:"
      echo "  hlc-recover status          # assess damage"
      echo "  hlc-recover wipe            # clean USB drives"
      echo "  hlc-recover sd-boot         # restore SD bootstrap boot"
      echo "  reboot -f                   # reboot into SD bootstrap"
      echo "  # then from workstation:  make provision HOST=$HOSTNAME"
    }

    cmd_status() {
      echo "=== HLC Recovery Status: $HOSTNAME ==="
      echo ""
      echo "--- Block devices (from /proc/partitions) ---"
      cat /proc/partitions 2>/dev/null
      echo ""
      echo "--- blkid ---"
      blkid 2>/dev/null
      echo ""
      echo "--- RAID status ---"
      cat /proc/mdstat 2>/dev/null
      echo ""
      echo "--- RAID detail ---"
      if [ -e "$RAID_DEV" ]; then
        mdadm --detail "$RAID_DEV" 2>/dev/null
      else
        # try alternate naming
        for md in /dev/md[0-9]*; do
          [ -e "$md" ] && mdadm --detail "$md" 2>/dev/null
        done
        [ $? -ne 0 ] && echo "(no RAID array found)"
      fi
      echo ""
      echo "--- Mount points ---"
      mount 2>/dev/null
      echo ""
      echo "--- SD card partitions ---"
      echo "  Firmware (FAT32): $FIRMWARE_DEV"
      blkid "$FIRMWARE_DEV" 2>/dev/null || echo "  (not found)"
      echo "  Bootstrap root:   $BOOTSTRAP_DEV"
      blkid "$BOOTSTRAP_DEV" 2>/dev/null || echo "  (not found)"
    }

    cmd_mount() {
      echo "==> Assembling RAID and mounting root..."

      if ! [ -e "$RAID_DEV" ]; then
        echo "--- Scanning for RAID arrays..."
        mdadm --assemble --scan 2>/dev/null
        sleep 2
      fi

      if ! [ -e "$RAID_DEV" ]; then
        echo "ERROR: RAID array $RAID_DEV not found after scan"
        echo "Run 'hlc-recover status' to inspect drives"
        return 1
      fi

      # RAID has a GPT partition table; root is partition 1
      RAID_PART=""
      for candidate in "''${RAID_DEV}p1" /dev/md/*p1 /dev/md[0-9]*p1; do
        if [ -e "$candidate" ]; then
          RAID_PART="$candidate"
          break
        fi
      done

      if [ -z "$RAID_PART" ]; then
        echo "ERROR: Cannot find RAID root partition (expected ''${RAID_DEV}p1)"
        echo "Check 'hlc-recover status' output"
        return 1
      fi

      mkdir -p "$RAID_MNT"
      if mount "$RAID_PART" "$RAID_MNT" 2>/dev/null; then
        echo "RAID root mounted at $RAID_MNT"
        echo "To unmount: hlc-recover umount"
      else
        echo "ERROR: Failed to mount $RAID_PART"
        echo "Try: e2fsck $RAID_PART"
        return 1
      fi
    }

    cmd_umount() {
      if mountpoint -q "$RAID_MNT" 2>/dev/null; then
        umount "$RAID_MNT" && echo "Unmounted $RAID_MNT"
      else
        echo "Nothing mounted at $RAID_MNT"
      fi
    }

    cmd_wipe() {
      FORCE=0
      [ "$1" = "-y" ] && FORCE=1

      echo "==> Wiping RAID for clean reprovision on $HOSTNAME..."
      echo ""
      echo "WARNING: This will destroy all data on the USB RAID array."
      echo "         SD card and NVMe are NOT touched."

      if [ "$FORCE" = "0" ]; then
        echo ""
        echo "Press Enter to continue or Ctrl+C to abort..."
        read _
      fi

      # Unmount if mounted
      cmd_umount 2>/dev/null

      # Stop all md arrays
      echo "--- Stopping RAID arrays..."
      if [ -e /dev/md/usb-raid ]; then
        mdadm --stop /dev/md/usb-raid 2>/dev/null && echo "  Stopped /dev/md/usb-raid"
      fi
      for md in /dev/md[0-9]*; do
        if [ -e "$md" ]; then
          mdadm --stop "$md" 2>/dev/null && echo "  Stopped $md"
        fi
      done

      echo "--- Wiping RAID superblocks on USB drives..."
      for dev in /dev/sd?; do
        if [ -e "$dev" ]; then
          # Wipe partition table and RAID metadata
          for part in "''${dev}"[0-9]*; do
            if [ -e "$part" ]; then
              mdadm --zero-superblock "$part" 2>/dev/null
              wipefs -a "$part" 2>/dev/null
              echo "  Wiped $part"
            fi
          done
          mdadm --zero-superblock "$dev" 2>/dev/null
          wipefs -a "$dev" 2>/dev/null
          sgdisk --zap-all "$dev" 2>/dev/null
          echo "  Wiped $dev"
        fi
      done

      echo ""
      echo "RAID wiped. USB drives are clean for reprovisioning."
      echo ""
      echo "Next steps:"
      echo "  1. Restore SD boot:  hlc-recover sd-boot"
      echo "  2. Reboot:           reboot -f"
      echo "  3. Reprovision:      make provision HOST=$HOSTNAME"
    }

    cmd_sdboot() {
      echo "==> Restoring SD card bootstrap boot files on $HOSTNAME..."

      mkdir -p "$FW_MNT"

      # Mount firmware partition
      if ! mount "$FIRMWARE_DEV" "$FW_MNT" 2>/dev/null; then
        echo "ERROR: Cannot mount firmware partition $FIRMWARE_DEV"
        return 1
      fi

      if [ -f "$FW_MNT/$BACKUP_NAME" ]; then
        echo "--- Found bootstrap backup ($BACKUP_NAME)"
        echo "--- Removing provisioned NixOS boot files..."
        # Remove NixOS generation dirs and config that reference RAID root
        rm -rf "$FW_MNT/nixos"
        # Preserve Pi firmware (.elf, .dat, .dtb, overlays) and the backup itself
        echo "--- Extracting bootstrap boot files..."
        cd "$FW_MNT"
        tar xzf "$FW_MNT/$BACKUP_NAME"
        sync
        echo ""
        echo "Bootstrap boot files restored successfully."
        echo "Next: reboot -f"
        echo "Node will boot into SD bootstrap mode for reprovisioning."
      else
        echo "No bootstrap backup found at $FW_MNT/$BACKUP_NAME"
        echo ""
        echo "This node was provisioned before the backup feature was added,"
        echo "or the backup was lost. You need to reflash the SD card:"
        echo ""
        echo "  1. Power off the node"
        echo "  2. On workstation: make build-image HOST=$HOSTNAME"
        echo "  3. Flash the SD card: make flash-image HOST=$HOSTNAME DEV=/dev/sdX"
        echo "  4. Reinsert SD card, power on"
        echo "  5. Reprovision: make provision HOST=$HOSTNAME"
      fi

      cd /
      umount "$FW_MNT" 2>/dev/null
    }

    case "$1" in
      status)  cmd_status ;;
      mount)   cmd_mount ;;
      umount)  cmd_umount ;;
      wipe)    shift; cmd_wipe "$@" ;;
      sd-boot) cmd_sdboot ;;
      *)       usage ;;
    esac
  '';
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
      "genet"        # bcmgenet NIC (Pi 4 and Pi 5)
      "md_mod"       # mdadm core
      "raid1"        # RAID-1 personality
      "usb_storage"  # USB mass storage (for RAID drives)
      "xhci_hcd"     # USB 3.0 host controller
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
        hostKeys = [ ../../../secrets/initrd/ssh_host_ed25519_key ];
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
