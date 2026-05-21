# Gibson hardware: NVIDIA RTX 3080 (Ampere), AMD Ryzen 9 5950X, PipeWire 5.1 surround.
# No laptop power management (TLP, thermald, lid switch) — desktop system.

{ config, pkgs, lib, ... }:

{
  # NVIDIA proprietary driver — RTX 3080 requires proprietary userspace
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Open kernel modules recommended for Ampere (Turing+) per NVIDIA guidance
    open = true;
    modesetting.enable = true;
    powerManagement.enable = true;
    # Do NOT use forceFullCompositionPipeline on multi-monitor — causes latency
    # and conflicts with picom vsync (nixpkgs #261112). Picom handles compositing.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    # Alternative: .latest — uncomment if stable has regressions
    # package = config.boot.kernelPackages.nvidiaPackages.latest;
  };

  # Vulkan + 32-bit support for Steam/Proton
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # AMD microcode updates
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # SSD health — periodic TRIM (weekly)
  services.fstrim.enable = true;

  # PipeWire 5.1 surround sound (onboard HD-Audio)
  # WirePlumber defaults to stereo; explicit profile selection required for surround
  services.pipewire.wireplumber.extraConfig = {
    # Pin onboard HD-Audio card to 5.1 surround + stereo mic input
    "90-onboard-surround" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            { "device.name" = "~alsa_card.pci.*"; "device.nick" = "~HD-Audio*"; }
          ];
          actions = {
            update-props = {
              "device.profile" = "output:analog-surround-51+input:analog-stereo";
            };
          };
        }
      ];
    };

    # Deprioritize NVIDIA HDMI audio so onboard analog is the default sink
    "91-nvidia-sink-priority" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            { "node.name" = "~alsa_output.*HDMI*"; }
          ];
          actions = {
            update-props = {
              "priority.driver" = 500;
              "priority.session" = 500;
            };
          };
        }
      ];
    };
  };
}
