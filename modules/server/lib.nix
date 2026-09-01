# Shared TLS plumbing for the server modules: chooses a LE-vs-bnuy cert, writes
# it somewhere nginx can read, and proxies a loopback app behind it. The three
# pieces the modules use:
#
#   mkTlsApp   - everything a public, nginx-proxied app needs (vhost + cert +
#                ACME), one call. (homepage, kuma, ntfy, jellyfin)
#   mkCertSync - just the cert-sync service/timer, for non-public vhosts or
#                apps that terminate TLS in the app (pterodactyl, technitium,
#                vaultwarden LAN vhost, mailcow nginx-ssl).
#   mkVhost    - an nginx reverse-proxy vhost against a loopback port. Used
#                directly by mkTlsApp and by the per-app modules that want
#                extra location blocks.
#
# LE challenge type:
#   http-01 (default) - webroot /var/lib/acme/acme-challenge, the same path
#     mail.bnuy.dev used for years. The -http vhost serves it.
#   dns01 (acmeDns = true) - tunneled hostnames route through the CF edge on
#     :80 too, so http-01 can't reach an origin vhost; lego proves the zone via
#     the Cloudflare DNS:Edit token (vpn/cf_dns_token) instead. REQUIRES the
#     acme-dns-public overlay: the box resolves through local Technitium, which
#     serves each splitDns FQDN as its OWN authoritative zone, so lego's SOA
#     walk would stop at e.g. "dash.bnuy.dev" and DNS-01 would silently never
#     issue (the old vaultwarden DNS-01 failure). The overlay points the acme
#     unit at public resolvers so the walk finds the real bnuy.dev zone.
#     vpn.bnuy.dev worked without the overlay only because it has no local zone.
#
# This file deliberately takes NO `config` argument: importing it from a
# module's top-level `let` with a config pass forces the whole fixpoint and
# deadlocks. Sops secret paths (the step-ca provisioner password) and
# stepCaRoot are passed in by each caller as plain strings, read inside the
# caller's own config block - the same laziness vaultwarden already relies on.
# Also: never read a caller option (cfg.domain) from a strict slot here - the
# asserts on acmeDomain/san were exactly that and recursed.
#
# Consumers:
#
#   let tls = (import ../lib.nix) { inherit lib pkgs; };
#   in config = lib.mkIf cfg.enable (lib.mkMerge [
#     { ...app... }
#     (tls.mkTlsApp {
#       name = "myapp";
#       domain = cfg.domain;
#       port = 8081;
#       passwordFile = config.sops.secrets."step-ca/password".path;
#     })
#   ]);
#
# Coupling (accepted, same as vaultwarden): step-ca must be enabled (for
# step-ca/password) wherever a module calls these. Secrets stay in sops -
# never in the Nix store.
{ lib, pkgs }:

let
  sslDirFor = name: "/var/lib/${name}-ssl";
  acmeDirFor = domain: "/var/lib/acme/${domain}";
  stepCaUrl = "https://127.0.0.1:9000";
  # bnuy CA root, copied into the store for step-cli --root on every cert sync.
  stepCaRoot = ./step-ca/root_ca.crt;

  # Trusted sources for LAN/VPN-only nginx gates: the LAN subnets + the tailnet
  # (100.64.0.0/10). deny all appended so the Cloudflare tunnel origin
  # (127.0.0.1) and any other source 403s -> public edges can never reach
  # through these vhosts. Keep in sync with services.vpn-server.acl.adminSubnets.
  vpnLanFence = lib.concatStringsSep "\n" (map (c: "allow ${c};") [
    "192.168.1.0/24"
    "192.168.2.0/24"
    "100.64.0.0/10"
  ]) + "\ndeny all;";

  # Bash: issue a bnuy step-ca leaf covering `san` into $file/$key.
  # Per-call tmp name so concurrent cert services don't collide.
  mkStepCaLeaf =
    { san, file, key, passwordFile }:
    let
      tmpCert = "/tmp/tls-${lib.last (lib.splitString "/" file)}";
      tmpKey = "/tmp/tls-${lib.last (lib.splitString "/" key)}";
    in
    ''
      ${pkgs.step-cli}/bin/step ca certificate \
        --ca-url ${stepCaUrl} \
        --root ${stepCaRoot} \
        --provisioner admin \
        --provisioner-password-file ${passwordFile} \
        --force ${lib.concatMapStringsSep " " (s: "--san ${s}") san} \
        ${lib.head san} ${tmpCert} ${tmpKey}
      install -o root -g nginx -m 0640 ${tmpCert} ${file}
      install -o root -g nginx -m 0640 ${tmpKey} ${key}
    '';

  # Bash: put the best available cert at $file/$key.
  #   le  -> the real LE cert when still valid (acme-success + 21 days),
  #          else a bnuy fallback leaf covering the domain.
  #   !le -> always a bnuy leaf covering `san`.
  mkCertBlock =
    { file, key, acmeDomain, le, san, passwordFile }:
    if le then
      let
        leCert = "${acmeDirFor acmeDomain}/fullchain.pem";
        leKey = "${acmeDirFor acmeDomain}/key.pem";
        leProved = "${acmeDirFor acmeDomain}/acme-success";
      in
      ''
        if [ -f ${leProved} ] \
           && [ -f ${leCert} ] && [ -f ${leKey} ] \
           && openssl x509 -checkend $((21 * 86400)) -noout -in ${leCert} 2>/dev/null; then
          install -o root -g nginx -m 0640 ${leCert} ${file}
          install -o root -g nginx -m 0640 ${leKey} ${key}
        else
          ${mkStepCaLeaf { inherit san; inherit file; inherit key; passwordFile = passwordFile; }}
        fi
      ''
    else
      mkStepCaLeaf { inherit san; inherit file; inherit key; passwordFile = passwordFile; };

  mkCertSync =
    { name
    , sslDir # absolute dir certs land in (nginx must be able to traverse it)
    , passwordFile
    , acmeDomain ? null # LE domain; null = bnuy-only
    , certs # list of { file key; le ? bool; san ? [names] }
    , extraScript ? ""
    , extraAfter ? [ ]
    , extraPath ? [ ]
    }:
    let
      certs' = map (c: {
        inherit (c) file key;
        le = c.le or false;
        # A cert's SANs: explicit `san`, else the acmeDomain. Every cert must
        # end up with at least one name to put in the bnuy leaf.
        san = c.san or (lib.optional (acmeDomain != null) acmeDomain);
      }) certs;
    in
    # ponytail: no asserts here - an assert forcing `cfg.domain` (the caller's
    # own option, read via acmeDomain) while the fixpoint is still def-collecting
    # is an infinite recursion (modules.nix:269). A wrong `san`/`acmeDomain`
    # still fails loudly at runtime when ./acme/<domain> doesn't exist.
    {
      systemd.services."${name}-cert" = {
        description = "${name}: sync TLS certs (LE primary, bnuy fallback)";
        wantedBy = [ "nginx.service" "multi-user.target" ];
        after = [
          "step-ca.service"
          "sops-nix.service"
        ] ++ lib.optionals (acmeDomain != null) [ "acme-${acmeDomain}.service" ] ++ extraAfter;
        # nginx's config references the cert files; never let it start (or get
        # reloaded by a switch) before they exist.
        before = [ "nginx.service" ];
        wants = [ "sops-nix.service" ];
        path = [ pkgs.openssl pkgs.coreutils pkgs.step-cli pkgs.systemd ] ++ extraPath;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = "on-failure";
          RestartSec = 30;
          TimeoutStartSec = 0;
        };
        script = ''
          set -eu
          mkdir -p ${sslDir}
          chown root:nginx ${sslDir}
          chmod 0750 ${sslDir}
          ${lib.concatStringsSep "\n" (
            map (c:
              mkCertBlock {
                inherit (c) file key san;
                acmeDomain = acmeDomain;
                le = c.le;
                passwordFile = passwordFile;
              }
            ) certs'
          )}
          ${extraScript}
          # Reload only when nginx is already up: on boot nginx starts after
          # us (before=nginx.service), and try-reload-or-restart would queue a
          # restart that deadlocks on the pending nginx start job. --no-block
          # keeps concurrent cert-syncs from deadlocking reload against each
          # other (a reload job orders behind the running sync whose own reload
          # call is waiting on it).
          systemctl is-active --quiet nginx.service \
            && systemctl reload nginx.service --no-block || true
        '';
      };
      systemd.timers."${name}-cert" = {
        description = "${name}: renew vhost TLS cert daily";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
        };
      };
    };

  mkVhost =
    { domain
    , port
    , sslDir
    , websockets ? false
    , extraConfig ? ""
    }:
    {
      ${domain} = {
        addSSL = true;
        http2 = true;
        # Pin 443 only (mail.bnuy.dev does the same): addSSL's default also
        # grabs port 80, which would shadow the *-http challenge vhost below
        # and make http-01 renewals 422.
        listen = [
          {
            addr = "0.0.0.0";
            port = 443;
            ssl = true;
          }
        ];
        sslCertificate = "${sslDir}/cert.pem";
        sslCertificateKey = "${sslDir}/key.pem";
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString port}";
          proxyWebsockets = websockets;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            ${extraConfig}
          '';
        };
      };
    };

  mkAcme =
    { domain
    , dns01 ? false # DNS-01 instead of http-01; cfTokenFile path required then
    , cfTokenFile ? null
    }:
    let
      cert =
        if dns01 then {
          # DNS-01: tunneled hostnames route through the Cloudflare edge on
          # :80 too, so http-01 can't reach the origin vhost; lego proves the
          # zone via the Cloudflare API instead (same token + precedent as
          # vpn.bnuy.dev). Port-80 vhosts keep serving a plain 301 redirect.
          dnsProvider = "cloudflare";
          credentialFiles.CF_DNS_API_TOKEN_FILE = cfTokenFile;
          group = "nginx";
        } else {
          # http-01 via the -http vhost's useACMEHost; served from the shared
          # webroot (/var/lib/acme/acme-challenge, same as mail.bnuy.dev).
          webroot = "/var/lib/acme/acme-challenge";
          group = "nginx";
        };
    in
    {
      security.acme = {
        acceptTerms = lib.mkDefault true;
        defaults.email = lib.mkDefault "enigma558@proton.me";
        certs.${domain} = cert;
      };
    } // lib.optionalAttrs dns01 {
      # DNS-01 zone-walk guard: the local Technitium answers authoritative
      # SOA for each public FQDN in splitDns (this box resolves through it),
      # so lego's SOA walk stops at e.g. "dash.bnuy.dev" (=its own local zone)
      # and never reaches the real bnuy.dev zone at the Cloudflare API -- the
      # cert stays stuck in Pending forever. Overlay a resolv.conf with PUBLIC
      # resolvers onto this acme unit so the walk finds the true zone (the
      # same resolution vpn.bnuy.dev got for free: no local zone for it).
      systemd.services.acme-dns-public = {
        description = "Write public-resolver resolv.conf for DNS-01 acme units";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = # `nameserver 1.1.1.1\nnameserver 8.8.8.8\n`
          ''
            mkdir -p /run/acme-dns-public
            printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /run/acme-dns-public/resolv.conf
            chmod 0644 /run/acme-dns-public/resolv.conf
          '';
      };
      systemd.services."acme-${domain}" = {
        after = [ "acme-dns-public.service" ];
        requires = [ "acme-dns-public.service" ];
        serviceConfig.BindReadOnlyPaths = [ "/run/acme-dns-public/resolv.conf:/etc/resolv.conf" ];
      };
      # The lego SOA walk itself runs in the order-renew unit on renewals and
      # at the end of the initial issue - it needs the same overlay.
      systemd.services."acme-order-renew-${domain}" = {
        after = [ "acme-dns-public.service" ];
        requires = [ "acme-dns-public.service" ];
        serviceConfig.BindReadOnlyPaths = [ "/run/acme-dns-public/resolv.conf:/etc/resolv.conf" ];
      };
    };

  # Everything a public, nginx-proxied app needs. Returns a config attrset to
  # merge (alongside the app's own systemd/nginx bits) under lib.mkIf cfg.enable.
  mkTlsApp =
    { name
    , domain
    , port
    , passwordFile
    , websockets ? true
    , extraVhostConfig ? ""
    , extraCertScript ? ""
    , acmeDns ? false # DNS-01 renewal (tunneled/external hostnames), not http-01
    , cfTokenFile ? null # required when acmeDns = true (vpn/cf_dns_token path)
    }:
    let
      sslDir = sslDirFor name;
    in
    # ponytail: these MUST merge recursively, not with shallow `//`. mkCertSync
    # and mkAcme (dns01) both emit `systemd.services.*`; a shallow `//` lets the
    # later one REPLACE the earlier `systemd` key and silently drops the
    # `<name>-cert` sync service (the reason no mkTlsApp app got one until
    # 2026-08-31). recursiveUpdate keeps both.
    lib.recursiveUpdate
      {
        services.nginx = {
          enable = lib.mkDefault true;
          virtualHosts = (mkVhost {
            inherit domain port sslDir websockets;
            extraConfig = extraVhostConfig;
          })
          // {
            # Port 80: serve the http-01 challenge (useACMEHost) + redirect the
            # rest. Mail's -http vhost uses the exact same shape.
            "${domain}-http" = {
              serverName = domain;
              listen = [
                {
                  addr = "0.0.0.0";
                  port = 80;
                }
              ];
              useACMEHost = domain;
              locations."/" = {
                extraConfig = "return 301 https://$host$request_uri;";
              };
            };
          };
        };
        # The LE challenge hits port 80; the firewall must allow it (ngnx
        # module already opens 443 for the TLS vhost).
        networking.firewall.allowedTCPPorts = [
          443
          80
        ];
      }
      (lib.recursiveUpdate (mkCertSync {
        inherit name sslDir passwordFile;
        extraScript = extraCertScript;
        acmeDomain = domain;
        certs = [
          {
            file = "${sslDir}/cert.pem";
            key = "${sslDir}/key.pem";
            le = true;
          }
        ];
      }) (mkAcme {
        inherit domain;
        dns01 = acmeDns;
        inherit cfTokenFile;
      }));
  # Pretty "access denied" landing for fence vhosts. Merge into a vhost that
  # returns 403 (e.g. vpnLanFence's `deny all`), so the client is served the
  # operator's 403 page (assets from config.services."403".assetsDir) rather
  # than nginx's bare 403 body. Never a real app (AGENTS posture 5). Because
  # callers combine this with their own extraConfig/locations, merge carefully:
  #   ... // (tls.fence403 { inherit assetsDir; })
  fence403 =
    { assetsDir }:
    {
      # Assets live in one store dedir with leaves 403.html/css/js; `root` finds
      # each by its own name. css/js load via relative <link>/<script> in the
      # html, so they must stay NON-internal (the browser fetches them directly).
      locations = {
        # `allow all` overrides any server/other-location-level `deny all`
        # inherited by these exact-match locations (essential when merged into
        # a 443 default stub that denies the whole vhost).
        "= /403.html" = { root = assetsDir; extraConfig = "allow all;"; };
        "= /403.css" = { root = assetsDir; extraConfig = "allow all;"; };
        "= /403.js" = { root = assetsDir; extraConfig = "allow all;"; };
      };
      extraConfig = "error_page 403 = /403.html;";
    };
in
{
  inherit mkTlsApp mkCertSync mkVhost mkAcme vpnLanFence fence403;
}