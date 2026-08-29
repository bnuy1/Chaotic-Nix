# Dynamic Cloudflare WAN-DNS updater ("DDNS for the home zone").
#
# The ISP rotates the WAN IPv4 without a reboot; this module detects the
# current address and reconciles a fixed list of grey-cloud (DNS-only) A
# records in one Cloudflare zone, deleting strays (wrong type, wildcard) that
# would shadow them. Cloudflare TUNNELS themselves are outbound-only and need
# no IP tracking — the records managed here exist because some services
# (Minecraft :25565, headscale/DERP :8443) must resolve the home IP directly.
#
# Self-contained: API token lives in THIS module's secrets.yaml
# (cloudflareDns/api_token), zone + record names come from host config via
# options. No coupling to sibling modules.
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.services.cloudflareDns;
in
{
  options.services.cloudflareDns = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the dynamic WAN-IP Cloudflare DNS reconciler";
    };

    zoneId = lib.mkOption {
      type = lib.types.str;
      description = "Cloudflare zone ID (dashboards -> domain -> overview)";
    };

    records = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      example = [ "bnuy.dev" "mc.bnuy.dev" ];
      description = ''
        DNS names that must always carry an A record pointing at the current
        WAN IPv4. Existing records for these names of ANY type are replaced,
        so a stray AAAA/CNAME can't shadow the grey A.
      '';
    };

    purgeWildcardName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "*.bnuy.dev";
      description = ''
        Wildcard record to delete on every run (null = don't care). Set this
        when the zone must NOT have a wildcard: an unconfigured subdomain
        would otherwise leak the home IP and hit port-forwards.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."cloudflareDns/api_token" = {
      sopsFile = ./secrets.yaml;
      owner = "root";
      mode = "0400";
    };

    systemd.services.cloudflare-dns = {
      description = "Cloudflare WAN DNS: reconcile grey-cloud A records with current WAN IP";
      after = [ "network-online.target" "sops-nix.service" ];
      wants = [
        "network-online.target"
        "sops-nix.service"
      ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.curl pkgs.jq ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 30;
      };
      script = ''
        set -eu
        TOKEN=$(cat ${config.sops.secrets."cloudflareDns/api_token".path})
        ZONE=${cfg.zoneId}
        API=https://api.cloudflare.com/client/v4

        # Detect the CURRENT WAN IPv4 — never hardcode it: the ISP rotates it
        # silently and a stale value fails exactly once everything else works.
        WAN=$(curl -4 -sf --max-time 10 https://www.cloudflare.com/cdn-cgi/trace | sed -n 's/^ip=//p' || true)
        if [ -z "$WAN" ]; then
          WAN=$(curl -4 -sf --max-time 10 https://api.ipify.org || true)
        fi
        if [ -z "$WAN" ]; then
          echo "WARN: could not detect WAN IPv4; leaving DNS untouched"
          exit 0
        fi

        ensure() {
          local name=$1
          # No-op when already correct so the frequent timer doesn't churn the
          # API or reset record TTLs.
          if curl -sf -H "Authorization: Bearer $TOKEN" \
            "$API/zones/$ZONE/dns_records?type=A&name=$name" \
            | jq -e --arg wan "$WAN" 'any(.result[]; .content == $wan)' >/dev/null; then
            return 0
          fi
          echo "updating $name -> $WAN"
          # Wrong or missing: delete ANY existing record for this name, then
          # recreate as a DNS-only A record (proxied would break raw TCP).
          for id in $(curl -sf -H "Authorization: Bearer $TOKEN" \
            "$API/zones/$ZONE/dns_records?name=$name" \
            | jq -r '.result[].id'); do
            curl -sf -X DELETE -H "Authorization: Bearer $TOKEN" \
              "$API/zones/$ZONE/dns_records/$id" >/dev/null || true
          done
          curl -sf -X POST -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            "$API/zones/$ZONE/dns_records" \
            -d "{\"type\":\"A\",\"name\":\"$name\",\"content\":\"$WAN\",\"proxied\":false,\"ttl\":1}" >/dev/null
        }

        ${lib.concatMapStringsSep "\n" (r: "ensure ${r}") cfg.records}

        ${lib.optionalString (cfg.purgeWildcardName != null) ''
          # Wildcards are not allowed in this zone: delete if someone re-adds
          # one (every unconfigured subdomain would hit the port-forward).
          for id in $(curl -sf -H "Authorization: Bearer $TOKEN" \
            "$API/zones/$ZONE/dns_records?type=A&name=${cfg.purgeWildcardName}" \
            | jq -r '.result[].id'); do
            curl -sf -X DELETE -H "Authorization: Bearer $TOKEN" \
              "$API/zones/$ZONE/dns_records/$id" >/dev/null || true
          done
        ''}
      '';
    };

    # The WAN can rotate at any moment, so boot-only runs miss it — re-check
    # shortly after boot and every 15 min thereafter.
    systemd.timers.cloudflare-dns = {
      description = "Cloudflare WAN DNS: re-check records every 15 min";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "15min";
        Persistent = true;
        Unit = "cloudflare-dns.service";
      };
    };
  };
}
