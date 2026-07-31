# plane — deck shared-service MicroVM (issue tracking / project management).
# depends on mothership.deck.network (br-deck).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.mothership.deck.plane;
in
{
  options.mothership.deck.plane = {
    enable = lib.mkEnableOption "Plane on the deck (shared service MicroVM)";
  };

  config = lib.mkIf cfg.enable {
    mothership.deck.network.enable = true;

    microvm.vms.plane = {
      autostart = true;

      config = {
        networking.hostName = "plane";

        networking.useNetworkd = true;
        systemd.network.enable = true;

        systemd.network.networks."10-eth" = {
          matchConfig.MACAddress = "02:00:00:00:00:20";

          address = [
            "10.42.0.20/16"
          ];

          routes = [
            {
              Gateway = "10.42.0.1";
            }
          ];

          networkConfig = {
            IPv6AcceptRA = false;
          };
        };

        microvm = {
          hypervisor = "cloud-hypervisor";

          vcpu = 2;
          mem = 4096;

          writableStoreOverlay = "/nix/.rw-store";

          volumes = [
            {
              image = "nix-store-overlay.img";
              mountPoint = "/nix/.rw-store";
              size = 8192;
            }
          ];

          shares = [
            {
              proto = "virtiofs";
              tag = "ro-store";
              source = "/nix/store";
              mountPoint = "/nix/.ro-store";
            }
            {
              proto = "virtiofs";
              tag = "persist";
              source = "/var/lib/mothership/deck/plane";
              mountPoint = "/persist";
            }
          ];

          interfaces = [
            {
              type = "tap";
              id = "plane0";
              mac = "02:00:00:00:00:20";
            }
          ];
        };
      };
    };

    system.activationScripts.mothership-deck-plane = lib.stringAfter [ "users" ] ''
      mkdir -p /var/lib/mothership/deck/plane
    '';

    systemd.services.microvm-br-plane = {
      description = "enslave plane0 → br-deck";
      after = [
        "systemd-networkd.service"
        "microvm-tap-interfaces@plane.service"
      ];
      requires = [ "microvm-tap-interfaces@plane.service" ];
      before = [ "microvm@plane.service" ];
      wantedBy = [ "microvm@plane.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.iproute2}/bin/ip link set dev plane0 master br-deck";
      };
    };
  };
}
