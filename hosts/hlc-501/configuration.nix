# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  raspberry-pi-nix.board = "bcm2712";

  networking.hostName = "hlc-501"; # Define your hostname.
  networking.useDHCP = true;

  services.openssh.enable = true;

  users.users.bob = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC2MfZmJMxQx3NGjPn92I1/n7pBTne/0aw0xVvgebFriN1UMKcEQagG3QzmM/4+zj001UGNKFK7FOlnTx6b8dz2mEC/ejYFG6R2Vtd6coxShjQDL2Nw3B/FMfky+jOBQ7viyODEiPhQlrO2FrQcd0BgjzHPvH0qtu12Ej2bo27abkIpyCEJyLf/xFKIyZ/RyFWaF8FOA4tpXpXvNa73QijvymMk2gY2HuLQVGYGPAVsLBEUbmAV7oN3inPcbawmjAgV5X23AoMr9F5pZbxdmZ61FUwWvaBjRdTopgfkI1RXZ52P27CJTjC3ndmlSgfV2Ht1iQ9VQmY5ShxFET9Wr6jz eaglerock@gibson"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
