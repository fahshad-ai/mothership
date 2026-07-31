# br-deck — private L2 for club services (mattermost, vault, grafana, loki).
# user VMs stay on the Headscale mesh, not on this bridge.
{
  config,
  lib,
  ...
}:
let
  cfg = config.mothership.deck.network;
in
{
  options.mothership.deck.network = {
    enable = lib.mkEnableOption "br-deck private bridge for deck services";

    address = lib.mkOption {
      type = lib.types.str;
      default = "10.42.0.1";
      description = "host address on br-deck";
    };

    prefixLength = lib.mkOption {
      type = lib.types.int;
      default = 16;
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.network.enable = true;

    systemd.network.netdevs."20-br-deck" = {
      netdevConfig = {
        Kind = "bridge";
        Name = "br-deck";
      };
    };

    systemd.network.networks."20-br-deck" = {
      matchConfig.Name = "br-deck";
      address = [ "${cfg.address}/${toString cfg.prefixLength}" ];
      networkConfig = {
        ConfigureWithoutCarrier = true;
        # no DHCP server yet — static IPs in each deck service module
      };
    };

    networking.firewall.trustedInterfaces = [ "br-deck" ];

    # isolate br-deck from member/user VMs. forward filtering only exists on
    # the nftables firewall, so deck pulls the nftables backend in with it.
    networking.nftables.enable = true;
    networking.firewall.backend = lib.mkDefault "nftables";
    networking.firewall.filterForward = true;
    networking.firewall.extraForwardRules = ''
      # member/user VMs keep their NAT'd internet access but never reach br-deck;
      # forward policy drops everything else, so deck stays private.
      iifname "br-members" oifname != "br-deck" accept
    '';

    # documentation for operators
    environment.etc."mothership/deck-network.txt".text = ''
      br-deck ${cfg.address}/${toString cfg.prefixLength}
      reserved:
        .1   host
        .10  mattermost
        .11  vaultwarden
        .12  grafana
        .13  loki
      user VMs: Headscale mesh only — not this bridge.
    '';
  };
}
