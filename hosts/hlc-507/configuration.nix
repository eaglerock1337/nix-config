# hlc-507 — Pi5 worker node
{ ... }:

{
  imports = [
    ../../modules/hardware/rpi5.nix
    ../../modules/users/operator.nix
    ../../modules/shell/common.nix
    ../../modules/shell/prompt.nix
    ../../modules/shell/utilities.nix
    ../../modules/motd/default.nix
    ../../modules/cluster/hlc/motd.nix
  ];

  networking.hostName = "hlc-507";
  networking.useDHCP = false;
  networking.interfaces.eth0.ipv4.addresses = [{
    address = "10.23.50.57";
    prefixLength = 24;
  }];
  networking.defaultGateway = "10.23.50.1";
  networking.nameservers = [ "10.23.50.1" ];

  users.operator.username = "bob";
  users.operator.sshKeys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC2MfZmJMxQx3NGjPn92I1/n7pBTne/0aw0xVvgebFriN1UMKcEQagG3QzmM/4+zj001UGNKFK7FOlnTx6b8dz2mEC/ejYFG6R2Vtd6coxShjQDL2Nw3B/FMfky+jOBQ7viyODEiPhQlrO2FrQcd0BgjzHPvH0qtu12Ej2bo27abkIpyCEJyLf/xFKIyZ/RyFWaF8FOA4tpXpXvNa73QijvymMk2gY2HuLQVGYGPAVsLBEUbmAV7oN3inPcbawmjAgV5X23AoMr9F5pZbxdmZ61FUwWvaBjRdTopgfkI1RXZ52P27CJTjC3ndmlSgfV2Ht1iQ9VQmY5ShxFET9Wr6jz eaglerock@gibson"
  ];

  # Cyan prompt — worker node
  shell.prompt.hostColor = "\\[\\033[36m\\]";

  services.openssh.enable = true;

  system.stateVersion = "25.11";
}
