#!/usr/bin/env bash
# wipe-disks.sh — Tear down RAID arrays and wipe USB drives for fresh provisioning.
#
# Run ON THE NODE (as root) before `make provision` from Gibson.
# Stops any active md arrays, zeros superblocks, wipes partition tables,
# and optionally wipes the NVMe if present.
#
# Usage:
#   sudo ./wipe-disks.sh                  # USB + RAID only, interactive
#   sudo ./wipe-disks.sh --yes            # skip confirmation (scripted use)
#   sudo ./wipe-disks.sh --wipe-nvme      # also wipe NVMe
#   sudo ./wipe-disks.sh --yes --wipe-nvme

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: must run as root" >&2
  exit 1
fi

YES=0
WIPE_NVME=0
for arg in "$@"; do
  case "$arg" in
    --yes) YES=1 ;;
    --wipe-nvme) WIPE_NVME=1 ;;
    *) echo "Unknown flag: $arg"; exit 1 ;;
  esac
done

# --- Detect USB drives ---
# Pi 5: fixed SoC xhci paths
# Pi 4: PCI-attached USB controller
USB_DRIVES=()
for p in /dev/disk/by-path/*-usb*-scsi-*; do
  [[ -e "$p" ]] || continue
  # resolve to the whole-disk device (strip partition suffix)
  resolved=$(readlink -f "$p")
  # skip partition devices — we want whole disks only
  case "$resolved" in
    *[0-9]p[0-9]*) continue ;;  # e.g. /dev/sda1 won't match, but nvme0n1p1 would
  esac
  # deduplicate
  if [[ ! " ${USB_DRIVES[*]:-} " =~ " ${resolved} " ]]; then
    USB_DRIVES+=("$resolved")
  fi
done

if [[ ${#USB_DRIVES[@]} -eq 0 ]]; then
  echo "ERROR: no USB drives found via /dev/disk/by-path/*-usb*-scsi-*" >&2
  echo "Check that drives are plugged in and detected: lsblk" >&2
  exit 1
fi

# --- Detect NVMe (only if --wipe-nvme) ---
NVME=""
if [[ $WIPE_NVME -eq 1 ]] && [[ -b /dev/nvme0n1 ]]; then
  NVME="/dev/nvme0n1"
fi

# --- Show what we'll wipe ---
echo "=== Disk wipe for fresh provisioning ==="
echo ""
echo "USB drives to wipe:"
for d in "${USB_DRIVES[@]}"; do
  echo "  $d ($(lsblk -dno SIZE "$d" 2>/dev/null || echo '???'))"
done
if [[ -n "$NVME" ]]; then
  echo "NVMe to wipe:"
  echo "  $NVME ($(lsblk -dno SIZE "$NVME" 2>/dev/null || echo '???'))"
elif [[ -b /dev/nvme0n1 ]]; then
  echo "NVMe detected but NOT wiping (use --wipe-nvme to include)"
fi
echo ""

# --- Existing md arrays ---
ACTIVE_MDS=()
for md in /dev/md/*; do
  [[ -e "$md" ]] || continue
  ACTIVE_MDS+=("$md")
done
if [[ ${#ACTIVE_MDS[@]} -gt 0 ]]; then
  echo "Active md arrays to stop:"
  for md in "${ACTIVE_MDS[@]}"; do
    echo "  $md"
  done
  echo ""
fi

if [[ $YES -eq 0 ]]; then
  read -rp "This will DESTROY all data on the above devices. Continue? [y/N] " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
fi

echo ""

# --- Step 1: unmount anything on these devices ---
echo "--- Unmounting filesystems..."
# unmount md arrays first
for md in "${ACTIVE_MDS[@]}"; do
  for mp in $(findmnt -rno TARGET -S "$md" 2>/dev/null || true); do
    echo "  umount $mp (from $md)"
    umount -l "$mp" 2>/dev/null || true
  done
done
# unmount USB partitions
for d in "${USB_DRIVES[@]}"; do
  for part in "${d}"*; do
    for mp in $(findmnt -rno TARGET -S "$part" 2>/dev/null || true); do
      echo "  umount $mp (from $part)"
      umount -l "$mp" 2>/dev/null || true
    done
  done
done
# unmount NVMe partitions
if [[ -n "$NVME" ]]; then
  for part in "${NVME}"*; do
    for mp in $(findmnt -rno TARGET -S "$part" 2>/dev/null || true); do
      echo "  umount $mp (from $part)"
      umount -l "$mp" 2>/dev/null || true
    done
  done
fi

# --- Step 2: stop md arrays ---
echo "--- Stopping md arrays..."
for md in "${ACTIVE_MDS[@]}"; do
  echo "  mdadm --stop $md"
  mdadm --stop "$md" 2>/dev/null || true
done
# also stop any auto-assembled arrays by scanning
mdadm --stop --scan 2>/dev/null || true

# --- Step 3: zero superblocks on all USB drive partitions ---
echo "--- Zeroing mdadm superblocks..."
for d in "${USB_DRIVES[@]}"; do
  for part in "${d}" "${d}"[0-9]* "${d}p"[0-9]*; do
    [[ -b "$part" ]] || continue
    echo "  mdadm --zero-superblock $part"
    mdadm --zero-superblock "$part" 2>/dev/null || true
  done
done

# --- Step 4: wipe partition tables ---
echo "--- Wiping partition tables (sgdisk --zap-all)..."
for d in "${USB_DRIVES[@]}"; do
  echo "  sgdisk --zap-all $d"
  sgdisk --zap-all "$d" 2>/dev/null || true
  # also wipe with wipefs for good measure
  wipefs -a "$d" 2>/dev/null || true
done

if [[ -n "$NVME" ]]; then
  echo "  sgdisk --zap-all $NVME"
  sgdisk --zap-all "$NVME" 2>/dev/null || true
  wipefs -a "$NVME" 2>/dev/null || true
fi

# --- Step 5: trigger udev to clear stale symlinks ---
echo "--- Settling udev..."
partprobe 2>/dev/null || true
udevadm trigger --subsystem-match=block
udevadm settle --timeout 30

echo ""
echo "=== Done. Drives are clean for \`make provision\`. ==="
echo ""
echo "Verify with: lsblk"
lsblk
