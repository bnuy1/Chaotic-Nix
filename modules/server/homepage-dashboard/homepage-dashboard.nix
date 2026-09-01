# Homepage dashboard (services.homepage-dashboard) - the landing page that
# links every other self-hosted app.
#
# Thin wrapper around the nixpkgs module (daemon, DynamicUser sandbox and
# declarative YAML generation already live there). This module adds only:
#   - a TLS vhost on shared 443 (mkTlsApp: LE via ACME http-01, bnuy fallback)
#   - HOMEPAGE_ALLOWED_HOSTS pinned to the domain so the app answers on it
#
# Everything visible on the dash is config/services/widgets below - fully
# declarative, rendered to /etc/homepage-dashboard/*.yaml at build time. So:
#   - no backups: the config IS nix.
#   - no email: homepage has no SMTP/notifications (mail sensor widgets excepted).
#   - no auth: homepage has no login. It's public by choice (see variables.nix
#     cloudflareDns.records); if you go private, flip serverModules to null and
#     drop the record - the vhost moves off public exposure automatically.
#
# The app itself binds 0.0.0.0:8086 (no bind option upstream); the host
# firewall never opens 8086, so only the local nginx proxy can reach it.

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.homepage-dashboard;
  tls = (import ../lib.nix) { inherit lib pkgs; };
in
{
  options.services.homepage-dashboard.domain = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = "dash.bnuy.dev";
    description = "Public vhost name (Cloudflare record + Technitium split-DNS handled at host level)";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      services.homepage-dashboard = {
        # 8086 - 8082 is mailcow's dockerized nginx on the host.
        listenPort = 8086;
        # nginx connects over 127.0.0.1:8086; the browser sends the real Host.
        allowedHosts = lib.mkDefault "localhost:8086,127.0.0.1:8086,${cfg.domain}";

        settings = {
          title = "Bnuy";
        };

        widgets = [
          {
            search = {
              provider = "duckduckgo";
              target = "_blank";
            };
          }
        ];

        # One tile per self-hosted service. Public FQDNs (they resolve to the
        # LAN IP via Technitium split-DNS, so they work from anywhere).
        services = [
          {
            "Info" = [
              {
                "Homepage" = {
                  href = "https://dash.bnuy.dev";
                  site = "https://github.com/gethomepage/homepage";
                  description = "This page";
                };
              }
              {
                "Status" = {
                  href = "https://kuma.bnuy.dev";
                  site = "https://github.com/louislam/uptime-kuma";
                  description = "Uptime monitoring";
                };
              }
              {
                "News" = {
                  href = "https://ntfy.bnuy.dev";
                  site = "https://github.com/binwiederhier/ntfy";
                  description = "Push notifications";
                };
              }
            ];
          }
          {
            "Media" = [
              {
                "Jellyfin" = {
                  href = "https://jellyfin.bnuy.dev";
                  site = "https://github.com/jellyfin/jellyfin";
                  description = "Movies and TV";
                };
              }
            ];
          }
          {
            "Accounts" = [
              {
                "Vaultwarden" = {
                  href = "https://password.bnuy.dev";
                  site = "https://github.com/dani-garcia/vaultwarden";
                  description = "Passwords";
                };
              }
              {
                "Mail" = {
                  href = "https://mail.bnuy.dev";
                  site = "https://mailcow.email/";
                  description = "Webmail";
                };
              }
              {
                "Panel" = {
                  href = "https://pterodactyl.network";
                  site = "https://pterodactyl.io/";
                  description = "Game panels";
                };
              }
            ];
          }
          {
            "Network" = [
              {
                "DNS" = {
                  href = "https://technitium.network";
                  site = "https://github.com/TechnitiumSoftware/DnsServer";
                  description = "Technitium DNS";
                };
              }
              {
                "VPN" = {
                  href = "https://vpn.bnuy.dev";
                  site = "https://github.com/juanfont/headscale";
                  description = "Headscale control plane";
                };
              }
            ];
          }
        ];
      };
    }

    # Public TLS vhost: LE via http-01 (shared webroot), bnuy step-ca fallback.
    (tls.mkTlsApp {
      name = "homepage-dashboard";
      domain = cfg.domain;
      port = 8086;
      websockets = false;
      passwordFile = config.sops.secrets."step-ca/password".path;
      acmeDns = true; # tunneled (Cloudflare edge fronts :80), so http-01 can't reach the origin
      cfTokenFile = config.sops.secrets."vpn/cf_dns_token".path;
      extraVhostConfig = "limit_req zone=bnuy_public burst=25 nodelay;";
    })
  ]);
}