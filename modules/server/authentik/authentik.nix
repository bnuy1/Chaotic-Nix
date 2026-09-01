# Authentik single-sign-on (IdP + nginx forward-auth) at auth.bnuy.dev.
#
# IdP of choice (AGENTS decision log 2026-08-30): identity + nginx forward-auth
# for apps that have NO native login wall (headscale panel, homepage management
# group). Apps with their own login (mailcow webmail, vaultwarden, ntfy,
# uptime-kuma) stay public with app-level auth — posture rule 2.
#
# Deployment: authentik's own docker compose (server + worker + postgres +
# redis), pinned images, fronted by the shared nginx on 443 at auth.bnuy.dev
# (LE DNS-01 via the tunnel edge).
#
# nginx forward-auth: OTHER modules' vhosts point `auth_request` at the
# authentik-managed proxy outpost via config.services.authentik.forwardAuth
# (see options doc below). The outpost is created in the authentik UI/API (a
# Proxy provider + Outpost, dockered provider bound to 127.0.0.1:9000) so
# host nginx can reach it, nothing else. NOT part of compose here — it is
# created post-bootstrap.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.authentik;
  tls = (import ../lib.nix) { inherit lib pkgs; };
  project = "authentik";
  dataDir = "/var/lib/authentik";
  # Compose YAML emitted verbatim into the seed unit. Postgres socket + the
  # proxy outpost 9000 publish to 127.0.0.1 only.
  composeYaml = ''
    x-authentik-base: &base
      image: ghcr.io/goauthentik/server:${cfg.imageTag}
      restart: unless-stopped
      networks:
        - authentik
      volumes:
        - ./media:/media
        - ./custom-templates:/templates
      environment:
        AUTHENTIK_REDIS__HOST: redis
        AUTHENTIK_POSTGRESQL__HOST: postgres
        AUTHENTIK_POSTGRESQL__PORT: 5432
        AUTHENTIK_POSTGRESQL__USER: authentik
        AUTHENTIK_POSTGRESQL__NAME: authentik
        AUTHENTIK_SECRET_KEY: "$AUTHENTIK_SECRET_KEY"
        AUTHENTIK_POSTGRESQL__PASSWORD: "$AUTHENTIK_POSTGRESQL__PASSWORD"
        AUTHENTIK_ERROR_REPORTING__ENABLED: "false"

    services:
      postgres:
        image: postgres:16-alpine
        restart: unless-stopped
        networks:
          - authentik
        volumes:
          - ./postgres-data:/var/lib/postgresql/data
        environment:
          POSTGRES_PASSWORD: "$AUTHENTIK_POSTGRESQL__PASSWORD"
          POSTGRES_USER: authentik
          POSTGRES_DB: authentik
        healthcheck:
          test: ["CMD-SHELL", "pg_isready -U authentik"]
          interval: 10s
          timeout: 5s
          retries: 5

      redis:
        image: redis:alpine
        restart: unless-stopped
        command: --save 60 1 --loglevel warning
        networks:
          - authentik
        volumes:
          - ./redis-data:/data
        healthcheck:
          test: ["CMD-SHELL", "redis-cli ping | grep PONG"]
          interval: 10s
          timeout: 5s
          retries: 5

      server:
        <<: *base
        command: server
        ports:
          - "127.0.0.1:8089:9000"
        depends_on:
          postgres:
            condition: service_healthy
          redis:
            condition: service_healthy

      worker:
        <<: *base
        command: worker
        user: root
        depends_on:
          postgres:
            condition: service_healthy
          redis:
            condition: service_healthy

    networks:
      authentik: {}
  '';
in
{
  options.services.authentik = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run the authentik IdP + forward-auth outpost";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "auth.bnuy.dev";
      description = "Public authentik vhost name";
    };

    imageTag = lib.mkOption {
      type = lib.types.str;
      default = "2026.8";
      description = "authentik server/worker/proxy image tag (must all match)";
    };

    # nginx auth_request block for one application vhost (no native login wall).
    # Merge into the app's vhost config:
    #   ... // (config.services.authentik.forwardAuth { flowSlug = "app-login-flow"; })
    # The outpost (Proxy provider + Outpost, docker provider bound to
    # 127.0.0.1:9000) must exist in authentik first (post-bootstrap; see header).
    forwardAuth = lib.mkOption {
      type = lib.types.unspecified;
      default =
        { flowSlug ? "default-authentication-flow" }:
        let
          redirect = "https://${cfg.domain}/if/flow/${flowSlug}/?next=$scheme://$host$request_uri";
        in
        {
          locations."/outpost.goauthentik.io" = {
            proxyPass = "http://127.0.0.1:9000";
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Original-URL $scheme://$host$request_uri;
              proxy_set_header X-Original-Method $request_method;
              proxy_set_header X-Original-URI $request_uri;
              proxy_set_header X-Forwarded-Prefix /outpost.goauthentik.io;
              proxy_set_header X-Authentik-Outpost-Prefix /outpost.goauthentik.io;
            '';
          };
          extraConfig = ''
            auth_request /outpost.goauthentik.io/auth/nginx;
            error_page 401 = @authentik;
            location @authentik {
              return 302 ${redirect};
            }
            # pass the Set-Cookie from the outpost back to the client so the
            # session cookie survives the subrequest.
            auth_request_set $auth_cookie $upstream_http_set_cookie;
            add_header Set-Cookie $auth_cookie;
          '';
        };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      virtualisation.docker.enable = true;

      sops.secrets."authentik/postgres_password" = {
        sopsFile = ./secrets.yaml;
        mode = "0400";
      };
      sops.secrets."authentik/secret_key" = {
        sopsFile = ./secrets.yaml;
        mode = "0400";
      };

      systemd.tmpfiles.rules = [
        "d ${dataDir} 0750 root docker -"
        # server/worker run as uid 1000 inside the container; media + custom
        # templates must be readable/writable by that uid (not root:docker).
        "d ${dataDir}/media 0750 1000 1000 -"
        "d ${dataDir}/custom-templates 0750 1000 1000 -"
        # re-assert owner/mode on already-created dirs at every boot
        "Z ${dataDir}/media 0750 1000 1000 -"
        "Z ${dataDir}/custom-templates 0750 1000 1000 -"
        "d ${dataDir}/postgres-data 0700 70 131 -"
        "d ${dataDir}/redis-data 0750 999 131 -"
      ];

      systemd.services.authentik-seed = {
        description = "authentik: write compose.yml from module";
        wantedBy = [ "multi-user.target" ];
        after = [ "sops-nix.service" ];
        wants = [ "sops-nix.service" ];
        path = [ pkgs.coreutils ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          set -eu
          mkdir -p ${dataDir}
          cat > ${dataDir}/compose.yml <<'EOF'
          ${composeYaml}
          EOF
          chown -R root:docker ${dataDir}
        '';
      };

      systemd.services.authentik = {
        description = "authentik IdP stack (server/worker/postgres/redis/proxy outpost)";
        after = [
          "docker.service"
          "authentik-seed.service"
          "network-online.target"
        ];
        requires = [ "authentik-seed.service" ];
        wants = [ "docker.service" "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = "on-failure";
          RestartSec = 30;
        };
        path = [ pkgs.docker pkgs.coreutils ];
        script = ''
          set -eu
          cd ${dataDir}
          AUTHENTIK_POSTGRESQL__PASSWORD="$(cat ${config.sops.secrets."authentik/postgres_password".path})" \
          AUTHENTIK_SECRET_KEY="$(cat ${config.sops.secrets."authentik/secret_key".path})" \
          docker compose -p ${project} up -d
        '';
      };
    }

    # Public TLS vhost at auth.bnuy.dev (LE DNS-01 through the tunnel edge).
    (tls.mkTlsApp {
      name = "authentik";
      domain = cfg.domain;
      port = 8089;
      websockets = true;
      passwordFile = config.sops.secrets."step-ca/password".path;
      acmeDns = true;
      cfTokenFile = config.sops.secrets."vpn/cf_dns_token".path;
      extraVhostConfig = "limit_req zone=bnuy_public burst=25 nodelay;";
    })
  ]);
}
