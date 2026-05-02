{ pkgs, ... }:

{
  # Isolated recovery toolbox for SD bootstrap closure.
  # Intentionally overlaps with modules/shell/utilities.nix (FR-003) — SD bootstrap
  # must not import the cluster toolbox module.
  environment.systemPackages = with pkgs; [
    curl        # HTTP fetches
    dmidecode   # hardware info
    dnsutils    # DNS diagnostics; provides dig/nslookup
    e2fsprogs   # ext4 filesystem tools
    git         # repo access
    gptfdisk    # GPT partition manipulation; provides sgdisk
    htop        # process monitor
    iproute2    # ip command
    util-linux  # block device tools; provides lsblk
    mdadm       # RAID management
    parted      # partition editor
    pciutils    # PCIe device info; provides lspci
    tmux        # terminal multiplexer
    usbutils    # USB device info; provides lsusb
    vim         # editor
    xfsprogs    # XFS filesystem tools
  ];
}
