{ config, lib, operatorPubkeys, ... }: {
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
    # Banner + quote sourced verbatim from sibling .txt files so the displayed
    # indent is preserved (Nix `''` indent-stripping would otherwise flatten it).
    cluster.motd.banner = builtins.readFile ./motd-banner.txt;
    cluster.motd.quote = builtins.readFile ./motd-quote.txt;

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
    home-manager.users.bob = import ../../../home/bob.nix;
  };
}
