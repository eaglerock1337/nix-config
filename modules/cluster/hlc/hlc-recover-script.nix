# hlc-recover: initrd recovery tool for HLC cluster nodes.
# Written as ash-compatible POSIX sh — the initrd shell is busybox, not bash.
# Build-time interpolation injects hostname for banner messages.
{ hostname }: ''
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
    echo "hlc-recover — recovery tool for $HOSTNAME"
    echo ""
    echo "Commands:"
    echo "  status      Show RAID, disk, and mount state"
    echo "  mount       Assemble RAID and mount root for inspection"
    echo "  umount      Unmount RAID root"
    echo "  raid-boot   Restore boot from existing RAID install (requires bootstrap userspace)"
    echo "  wipe [-y]   Stop RAID, wipe USB superblocks (prepares for reprovision)"
    echo "  sd-boot     Restore SD card bootstrap boot files"
    echo ""
    echo "Typical recovery flow:"
    echo "  hlc-recover status          # assess damage"
    echo "  hlc-recover wipe            # clean USB drives"
    echo "  hlc-recover sd-boot         # restore SD bootstrap boot"
    echo "  reboot -f                   # reboot into SD bootstrap"
    echo "  # then from workstation:  make provision HOST=$HOSTNAME"
    echo ""
    echo "Restore RAID boot after SD reflash:"
    echo "  hlc-recover raid-boot       # reinstall bootloader from RAID system"
    echo "  reboot                      # boot into provisioned system"
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

    # Always run e2fsck before mount — the RAID is never cleanly unmounted
    # when the node is power-cycled to flash a new SD card, so the journal
    # will need recovery every time.
    echo "--- Running e2fsck on $RAID_PART..."
    e2fsck -y "$RAID_PART" 2>&1 || true

    mkdir -p "$RAID_MNT"
    if mount "$RAID_PART" "$RAID_MNT" 2>/dev/null; then
      echo "RAID root mounted at $RAID_MNT"
      echo "To unmount: hlc-recover umount"
    else
      echo "ERROR: Failed to mount $RAID_PART"
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

  cmd_raidboot() {
    echo "==> Restoring boot from RAID on $HOSTNAME..."

    # This command requires chroot (full bootstrap userspace, not initrd)
    if ! command -v chroot >/dev/null 2>&1; then
      echo "ERROR: chroot not available — this command requires the SD bootstrap userspace."
      echo "       It cannot run from the initrd rescue shell."
      return 1
    fi

    # Mount RAID if not already mounted
    if ! mountpoint -q "$RAID_MNT" 2>/dev/null; then
      cmd_mount || return 1
    fi

    # Verify system profile exists on the RAID
    # Use -L (symlink exists) not -e (target exists): the profile is a symlink
    # to an absolute /nix/... path that only resolves inside a chroot, not from
    # the host SD root.
    SYSTEM="$RAID_MNT/nix/var/nix/profiles/system"
    if ! [ -L "$SYSTEM" ]; then
      echo "ERROR: No NixOS system profile found at $SYSTEM"
      echo "The RAID does not have a complete NixOS installation."
      return 1
    fi

    echo "--- System: $(ls -l "$SYSTEM")"

    # Mount firmware partition inside RAID mount for the bootloader installer
    mkdir -p "$RAID_MNT/boot/firmware"
    if ! mount "$FIRMWARE_DEV" "$RAID_MNT/boot/firmware"; then
      echo "ERROR: Cannot mount $FIRMWARE_DEV at $RAID_MNT/boot/firmware"
      return 1
    fi

    # Bind-mount virtual filesystems for chroot
    # --make-rslave prevents mount propagation from chroot back to host,
    # which otherwise breaks /dev/pts and makes sudo unusable.
    mount -t proc proc "$RAID_MNT/proc"
    mount --rbind /sys "$RAID_MNT/sys"
    mount --make-rslave "$RAID_MNT/sys"
    mount --rbind /dev "$RAID_MNT/dev"
    mount --make-rslave "$RAID_MNT/dev"

    echo "--- Running bootloader installer via chroot..."
    chroot "$RAID_MNT" /nix/var/nix/profiles/system/bin/switch-to-configuration boot
    rc=$?

    # Cleanup
    umount "$RAID_MNT/boot/firmware" 2>/dev/null
    umount -l "$RAID_MNT/proc" 2>/dev/null
    umount -l "$RAID_MNT/sys" 2>/dev/null
    umount -l "$RAID_MNT/dev" 2>/dev/null

    if [ $rc -eq 0 ]; then
      echo ""
      echo "Boot restored from RAID successfully."
      echo "Next: reboot"
    else
      echo ""
      echo "ERROR: Bootloader installation failed (exit $rc)"
      echo "Check the output above for details."
      return 1
    fi
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
    status)    cmd_status ;;
    mount)     cmd_mount ;;
    umount)    cmd_umount ;;
    raid-boot) cmd_raidboot ;;
    wipe)      shift; cmd_wipe "$@" ;;
    sd-boot)   cmd_sdboot ;;
    *)         usage ;;
  esac
''
