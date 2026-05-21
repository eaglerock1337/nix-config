{ config, lib, operatorPubkeys, ... }:
let
  esc = builtins.fromJSON ''"\u001b"'';
  gold = "${esc}[38;5;214m";
  teal = "${esc}[38;5;109m";
  green = "${esc}[38;5;142m";
  red = "${esc}[38;5;167m";
  reset = "${esc}[0m";
in {
  imports = [
    ./options.nix
    ../common.nix
    ./hosts.nix
    ./raid-fallback.nix
  ];

  config = {
    # networking.fqdn is auto-derived as "${hostName}.${domain}" — do NOT assign directly
    networking.domain = "marks.dev";

    # Allow bob to receive nix store paths via `nix copy` from gibson (W-012).
    nix.settings.trusted-users = [ "root" "bob" ];

    # HLC MOTD content (cluster.motd mechanism in modules/cluster/motd.nix).
    # Colored inline — 256-color Gruvbox palette.
    cluster.motd.banner = builtins.concatStringsSep "\n" [
      "${gold}  ##########################################${reset}"
      "${gold}  #${teal}             __  ____    ______         ${gold}#${reset}"
      "${gold}  #${teal}            / / / / /   / ____/         ${gold}#${reset}"
      "${gold}  #${teal}           / /_/ / /   / /              ${gold}#${reset}"
      "${gold}  #${teal}          / __  / /___/ /___            ${gold}#${reset}"
      "${gold}  #${teal}         /_/ /_/_____/\\____/            ${gold}#${reset}"
      "${gold}  #                                        #${reset}"
      "${gold}  #          \"${green}Happy Little Cloud${gold}\"          #${reset}"
      "${gold}  #                                        #${reset}"
      "${gold}  ##########################################${reset}"
    ];
    cluster.motd.quote = ''
      ${gold}  "${teal}Let's build just a happy little cloud.${gold}"${reset}
                                        ${gold}~${reset} ${red}Bob Ross${reset}'';

    # Wire HLC glyph into the generic cluster prompt mechanism
    cluster.prompt.glyph = config.hlc.prompt.glyph;

    # HLC cluster operator
    system.operator = {
      name = "bob";
      pubkeys = operatorPubkeys;
      description = "HLC cluster operator";
    };

    # Home-manager bindings for the operator
    home-manager.extraSpecialArgs = { };
    home-manager.users.bob = import ../../../../home/bob.nix;
  };
}
