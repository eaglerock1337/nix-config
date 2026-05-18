{ config, lib, pkgs, ... }:
# One-shot EEPROM config service
# Applies boot-order and Pi-family-specific EEPROM settings on first boot.
# Idempotent: gated by marker file /boot/firmware/.eeprom-configured.
#
# Imported by both modules/hardware/rpi4.nix and modules/hardware/rpi5.nix.
# The hlc.piFamily option (set in each hardware module) gates Pi 5-only settings.
let
  isRpi5 = config.hlc.piFamily == "rpi5";

  eepromConfig = pkgs.writeText "hlc-eeprom-config.txt" (''
    # Boot order: USB first (4), SD fallback (1), repeat (f) — BOOT_ORDER=0xf14
    # Means: try USB mass storage → try SD card → repeat
    BOOT_ORDER=0xf14
    # Log firmware boot decisions over GPIO UART (useful for headless debug)
    BOOT_UART=1
  '' + lib.optionalString isRpi5 ''
    # Pi 5 only: no GPIO wake source in rack environment
    WAKE_ON_GPIO=0
    # Pi 5 only: poweroff actually cuts power (useful with centralized switching)
    POWER_OFF_ON_HALT=1
  '');
in {
  options.hlc.piFamily = lib.mkOption {
    type = lib.types.enum [ "rpi4" "rpi5" ];
    default = "rpi4";
    description = "Raspberry Pi hardware family. Set in rpi4.nix or rpi5.nix.";
  };

  config = {
    environment.systemPackages = [ pkgs.raspberrypi-eeprom ];

    systemd.services.rpi-eeprom-config = {
      description = "Configure Raspberry Pi EEPROM boot settings (one-shot)";
      # Run once after the firmware partition is mounted
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Script runs as root; /boot/firmware must be mounted
        ExecStart = pkgs.writeShellScript "apply-rpi-eeprom-config" ''
          set -euo pipefail
          MARKER=/boot/firmware/.eeprom-configured
          if [ -f "$MARKER" ]; then
            echo "rpi-eeprom: EEPROM already configured (marker present)"
            exit 0
          fi
          echo "rpi-eeprom: applying EEPROM config..."
          ${pkgs.raspberrypi-eeprom}/bin/rpi-eeprom-config --apply ${eepromConfig}
          touch "$MARKER"
          echo "rpi-eeprom: done. Boot order and UART logging set."
        '';
      };
    };
  };
}
