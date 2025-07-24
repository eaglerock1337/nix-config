{ config, pkgs, lib, ... }:

{
  imports = [ ];

  # Enable firmware updates
  services.fwupd.enable = true;

  services.logind = {
    lidSwitch = "suspend";
    lidSwitchDocked = "ignore";
    lidSwitchExternalPower = "suspend";
  };

  services.power-profiles-daemon.enable = false; # Use TLP instead

  # Power management with TLP (fine-grained) or power-profiles-daemon (auto)
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "fpowersave";
      USB_AUTOSUSPEND = 1;
      WIFI_PWR_ON_BAT = "on";
      PCIE_ASPM_ON_BAT = "powersupersave";
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 95;
    };
  };

  # Intel optimizations
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      mesa
      vulkan-loader
      vulkan-tools
      vulkan-headers
      intel-media-driver
    ];
  };

  # Fan and thermal management
  # Some models support thinkfan; enable only if supported
  services.thinkfan.enable = true;

  # Enable thermald for CPU thermal management (especially useful on Intel)
  services.thermald.enable = true;

  # Laptop-specific drivers
  services.acpid.enable = true;

  # Touchpad and TrackPoint
  services.libinput = {
    enable = true;
    touchpad = {
      disableWhileTyping = true;
      tapping = true;
      naturalScrolling = true;
    };
  };

  # Backlight & brightness
  hardware.brillo.enable = true;

  # Optional: kernel modules for Lenovo features
  boot.kernelModules = [
    "thinkpad_acpi"
    "acpi_call"
  ];

  environment.systemPackages = with pkgs; [
    powertop
    fwupd
    lm_sensors
    brightnessctl
  ];

  # Optional: systemd tweaks
  systemd.services."tlp-resume" = {
    enable = true;
    description = "Restart TLP after resume";
    serviceConfig = {
      ExecStart = "${pkgs.tlp}/bin/tlp start";
    };
    wantedBy = [ "resume.target" ];
  };
}
