# Cluster Preparation Guide

This guide covers the physical preparation of the Happy Little Cloud NixOS cluster.

## Cluster Overview

| Node | Hostname | FQDN | IP | Role |
|------|----------|------|-----|------|
| Pi4 #1 | hlc-401 | hlc-401.marks.dev | 10.23.50.41 | Control Plane (init) |
| Pi4 #2 | hlc-402 | hlc-402.marks.dev | 10.23.50.42 | Control Plane |
| Pi4 #3 | hlc-403 | hlc-403.marks.dev | 10.23.50.43 | Control Plane |
| Pi4 #4 | hlc-404 | hlc-404.marks.dev | 10.23.50.44 | Control Plane |
| Pi5 #1 | hlc-501 | hlc-501.marks.dev | 10.23.50.51 | Worker |
| Pi5 #2 | hlc-502 | hlc-502.marks.dev | 10.23.50.52 | Worker |
| Pi5 #3 | hlc-503 | hlc-503.marks.dev | 10.23.50.53 | Worker |
| Pi5 #4 | hlc-504 | hlc-504.marks.dev | 10.23.50.54 | Worker |
| Pi5 #5 | hlc-505 | hlc-505.marks.dev | 10.23.50.55 | Worker |
| Pi5 #6 | hlc-506 | hlc-506.marks.dev | 10.23.50.56 | Worker |
| Pi5 #7 | hlc-507 | hlc-507.marks.dev | 10.23.50.57 | Worker |
| Pi5 #8 | hlc-508 | hlc-508.marks.dev | 10.23.50.58 | Worker |

---

## Storage Architecture

### Per-Node Storage Layout

Each node uses a 3-tier storage approach:

| Layer | Device | Size | Purpose |
|-------|--------|------|---------|
| `/boot` | MicroSD (Class 10 A1) | 32GB | Firmware, kernel, initramfs |
| `/` (root) | 2x USB 3.2 (RAID1 mirror) | 32GB each | NixOS, etcd, logs |
| Longhorn | NVMe (Pi5 only) | 1TB | Distributed storage |

### Total Hardware Inventory

| Component | Quantity | Per Node | Notes |
|-----------|----------|----------|-------|
| MicroSD Class 10 A1 | 12+ | 1 | Plus extras for recovery |
| USB 3.2 32GB drives | 24 | 2 | Mirrored pair per node |
| Corsair MP600 Micro 1TB NVMe | 8 | 1 (Pi5 only) | For Longhorn storage |

### Throughput Expectations

| Device | Sequential Read | Sequential Write | Random IOPS | Notes |
|--------|----------------|------------------|-------------|-------|
| **MicroSD Class 10 A1** | ~100 MB/s | ~30 MB/s | 1,500 / 500 | Adequate for /boot |
| **USB 3.2 Gen 1** | ~300 MB/s | ~200 MB/s | ~5,000 | Capped by Pi USB 3.0 |
| **Corsair MP600 Micro** | 5,100 MB/s | 4,800 MB/s | ~700,000 | **Bottlenecked by Pi5 PCIe** |

### Pi Interface Limitations

| Interface | Pi4 | Pi5 | Practical Throughput |
|-----------|-----|-----|---------------------|
| USB 3.0 | 5 Gbps | 5 Gbps | ~400 MB/s |
| PCIe | N/A | 2.0 x1 | ~500 MB/s |
| MicroSD | UHS-I | UHS-I | ~100 MB/s |

**Important:** The Pi5's PCIe 2.0 x1 interface bottlenecks the NVMe (rated 5,100 MB/s) to ~400-500 MB/s. Still excellent for IOPS-heavy workloads like databases.

**Source:** [Raspberry Pi 5 Specifications](https://www.raspberrypi.com/products/raspberry-pi-5/specifications/)

### Why This Architecture?

1. **MicroSD for /boot**: No EEPROM/boot order changes needed, easy recovery
2. **USB RAID1 for root**: Survives drive failure, much better write endurance than SD
3. **NVMe for Longhorn**: Massive IOPS advantage (700K vs 5K) for persistent volumes

---

## Step 1: Build NixOS Installer Images

The [nixos-raspberrypi](https://github.com/nvmd/nixos-raspberrypi) project provides pre-configured NixOS images for Raspberry Pi.

```bash
cd ~/git/nix-config

# Add the binary cache for faster builds (optional but recommended)
# See: https://github.com/nvmd/nixos-raspberrypi#binary-cache

# Build RPi4 installer image (control plane nodes)
nix build github:nvmd/nixos-raspberrypi#installerImages.rpi4 -o rpi4-image

# Build RPi5 installer image (worker nodes)
nix build github:nvmd/nixos-raspberrypi#installerImages.rpi5 -o rpi5-image
```

The images will be in:
- `./rpi4-image/sd-image/nixos-sd-image-*.img`
- `./rpi5-image/sd-image/nixos-sd-image-*.img`

**Source:** [nixos-raspberrypi README - Installer Images](https://github.com/nvmd/nixos-raspberrypi#installer-images)

---

## Step 2: Flash MicroSD Cards (Boot Layer)

The MicroSD provides the initial boot layer with firmware and kernel.

### Identify Your SD Card

```bash
# List block devices (SD card reader often appears as mmcblk0 or sdX)
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL
```

**WARNING:** Double-check the device name! Flashing to the wrong device will destroy data.

### Flash MicroSD Cards

```bash
# Flash RPi4 image to MicroSD (repeat for hlc-401 through hlc-404)
sudo dd if=./rpi4-image/sd-image/nixos-sd-image-*.img of=/dev/mmcblkX bs=4M status=progress conv=fsync

# Flash RPi5 image to MicroSD (repeat for hlc-501 through hlc-508)
sudo dd if=./rpi5-image/sd-image/nixos-sd-image-*.img of=/dev/mmcblkX bs=4M status=progress conv=fsync

sync
```

### Label Your MicroSD Cards

Label each MicroSD with its hostname using a fine-tip marker or label maker.

---

## Step 3: Prepare USB Drive Pairs (Root Filesystem)

Each node gets 2x USB 3.2 drives that will be configured as a RAID1 mirror for the root filesystem.

### Initial USB Preparation

For the **initial boot**, we need one USB drive with a basic partition. After boot, we'll set up the RAID mirror.

```bash
# Identify USB drives
lsblk -o NAME,SIZE,TYPE,MODEL

# For initial setup, partition ONE USB drive per node
# (The RAID mirror will be configured after first boot)
sudo fdisk /dev/sdX
# Create a single Linux partition using the entire disk
# n -> p -> 1 -> Enter -> Enter -> w

# Format as ext4 (temporary - will be replaced by RAID)
sudo mkfs.ext4 -L NIXOS_USB /dev/sdX1
```

### Label USB Drives

Label each USB drive pair:
- `hlc-401-A` and `hlc-401-B`
- `hlc-402-A` and `hlc-402-B`
- etc.

**Source:** [NixOS Manual - File Systems](https://nixos.org/manual/nixos/stable/#sec-filesystems)

---

## Step 4: Boot Architecture

With MicroSD as the boot layer, no EEPROM changes are needed. The Pi will:

1. Boot from MicroSD (firmware + kernel + initramfs)
2. Mount root filesystem from USB (or USB RAID1 after setup)
3. NVMe remains available for Longhorn (Pi5 only)

### Why MicroSD + USB?

| Benefit | Description |
|---------|-------------|
| No EEPROM changes | Works out of the box on any Pi4/Pi5 |
| Easy recovery | Swap MicroSD to reinstall, USB data intact |
| Better reliability | USB RAID1 survives drive failure |
| Simple provisioning | Flash SD, boot, configure USB mirror |

**Source:** [Raspberry Pi Documentation - Boot](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#raspberry-pi-bootloader-configuration)

---

## Step 5: Network Configuration (Unifi)

Set up static DHCP reservations in your Unifi controller.

### Get MAC Addresses

On first boot, each Pi will get a DHCP address. SSH in and get the MAC:

```bash
# SSH to the Pi (default user: nixos, no password)
ssh nixos@<dhcp-assigned-ip>

# Get MAC address
ip link show eth0 | grep ether
```

### Create DHCP Reservations

In Unifi Controller:
1. Go to **Settings** → **Networks** → **Your Network** → **DHCP**
2. Add static reservations:

| MAC Address | IP Address | Hostname |
|-------------|------------|----------|
| (from Pi4 #1) | 10.23.50.41 | hlc-401 |
| (from Pi4 #2) | 10.23.50.42 | hlc-402 |
| ... | ... | ... |

### DNS Records (Optional)

Add A records for `.marks.dev`:
```
hlc-401.marks.dev -> 10.23.50.41
hlc-402.marks.dev -> 10.23.50.42
...
```

---

## Step 6: First Boot Checklist

For each Pi, after inserting the USB drive and powering on:

### 1. SSH Into the Node

```bash
ssh nixos@<ip-address>
# No password required for initial boot
```

### 2. Record System Information

```bash
# Get MAC address for DHCP reservation
ip link show eth0 | grep ether

# Verify it's the right Pi model
cat /proc/cpuinfo | grep Model

# Check NVMe is detected (Pi5 workers only)
lsblk | grep nvme
```

### 3. Generate Age Key for sops-nix

Each node needs an age keypair for secrets decryption.

```bash
# Create sops-nix key directory
sudo mkdir -p /var/lib/sops-nix

# Generate age keypair
sudo age-keygen -o /var/lib/sops-nix/keys.txt

# Display the public key (you'll need this for .sops.yaml)
sudo cat /var/lib/sops-nix/keys.txt | grep "public key"
```

**Record the public key** - you'll add it to `.sops.yaml` in the nix-config repo.

**Source:** [sops-nix - Usage](https://github.com/Mic92/sops-nix#usage)

### 4. Set Root Password (Temporary)

```bash
sudo passwd root
```

---

## Step 7: Collect Information

Create a tracking document with info from each node:

```markdown
## hlc-401 (Pi4 Control Plane - Init)
- MAC: xx:xx:xx:xx:xx:xx
- IP: 10.23.50.41
- Age Public Key: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

## hlc-402 (Pi4 Control Plane)
- MAC: xx:xx:xx:xx:xx:xx
- IP: 10.23.50.42
- Age Public Key: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

... (repeat for all 12 nodes)
```

---

## Step 8: Verify NVMe Storage (Pi5 Workers Only)

On each Pi5 worker, verify the NVMe drive is detected:

```bash
# List NVMe devices
lsblk | grep nvme

# Check NVMe health
sudo nvme smart-log /dev/nvme0n1

# Verify size (should be ~1TB)
lsblk -o NAME,SIZE,MODEL | grep nvme
```

The NVMe drives will be formatted and managed by Longhorn after cluster deployment.

---

## Step 9: Setup USB RAID1 Mirror (Post-First-Boot)

After the initial boot, configure the USB RAID1 mirror for the root filesystem.

### Install Required Tools

```bash
# mdadm for software RAID
sudo nix-env -iA nixos.mdadm
```

### Create RAID1 Array

```bash
# Identify both USB drives (should be sda and sdb, verify!)
lsblk -o NAME,SIZE,MODEL

# Create RAID1 array
sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sda1 /dev/sdb1

# Watch sync progress
watch cat /proc/mdstat
```

### Format and Mount

```bash
# Format the RAID array
sudo mkfs.ext4 -L NIXOS_ROOT /dev/md0

# Mount and copy root filesystem
sudo mount /dev/md0 /mnt
sudo rsync -aAXv / /mnt --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"}
```

### Update NixOS Configuration

The final NixOS configuration will include RAID setup declaratively. This manual step is for initial provisioning only.

**Source:** [NixOS Wiki - RAID](https://wiki.nixos.org/wiki/RAID)

---

## Step 10: Create Recovery MicroSD (Stretch Goal)

Keep a spare MicroSD with a full bootable NixOS image for each Pi type:

```bash
# Flash a complete recovery image
sudo dd if=./rpi4-image/sd-image/nixos-sd-image-*.img of=/dev/mmcblkX bs=4M status=progress conv=fsync

# Label as "RECOVERY-Pi4" or "RECOVERY-Pi5"
```

If a node fails:
1. Insert recovery MicroSD
2. Boot to recovery environment
3. Diagnose/repair USB RAID
4. Reboot with original MicroSD

---

## Step 11: Update Your Laptop

While preparing the cluster hardware, update your laptop:

```bash
cd ~/git/nix-config

# Update flake inputs
nix flake update

# Dry-run first (always!)
ndr

# Apply if dry-run succeeds
nr
```

---

## Next Steps

Once all nodes are booted and you have:
- [ ] All 12 USB drives flashed and labeled
- [ ] All 12 nodes booted successfully
- [ ] MAC addresses recorded for each node
- [ ] DHCP reservations configured
- [ ] Age public keys collected from each node

You're ready to proceed with NixOS configuration deployment. Run:

```bash
@nixy-boi Let's deploy the cluster configuration
```

---

## Troubleshooting

### Pi Won't Boot from USB

1. Try a different USB port (use USB 3.0 blue ports)
2. Check EEPROM boot order (see Step 3)
3. Try a different USB drive (some are incompatible)
4. Boot from SD card first to update EEPROM

### Can't SSH to Node

1. Check network cable connection
2. Verify DHCP server is running
3. Check Unifi controller for assigned IP
4. Try `nmap -sn 10.23.50.0/24` to find devices

### NVMe Not Detected (Pi5)

1. Reseat the M.2 HAT connection
2. Check HAT power requirements
3. Verify NVMe drive is seated properly
4. Try `dmesg | grep nvme` for errors

---

## References

- [nixos-raspberrypi](https://github.com/nvmd/nixos-raspberrypi) - NixOS Raspberry Pi support
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [sops-nix](https://github.com/Mic92/sops-nix) - Secrets management
- [Raspberry Pi USB Boot](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#usb-mass-storage-boot)
- [Longhorn Documentation](https://longhorn.io/docs/)
