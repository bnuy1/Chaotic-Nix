# Authentik (SSO/IdP) CHANGES

## 2026-08-31 — greenfield authentik deployment (services.authentik)

- New self-contained sub-module `modules/server/authentik` (path flake, mirrors
  the `vaultwarden` pattern): `services.authentik`, enabled on singularity.
- Deploys authentik `2026.8` (>= operator's 2026.2.3 / 2025.12.5 floor for
  GHSA-5wcc-hf24-rf5h) via docker compose: `server`, `worker`, `postgres:16`,
  `redis`. Proxy outpost is NOT in compose — it is created in authentik
  post-bootstrap (Proxy provider + Outpost, docker provider bound to
  127.0.0.1:9000).
- Public vhost `auth.bnuy.dev` (`mkTlsApp`, LE DNS-01 through the Cloudflare
  tunnel edge, `limit_req`). Added `auth.bnuy.dev` to cloudflare-tunnel hosts.
- sops secrets: `authentik/postgres_password`, `authentik/secret_key`
  (`secrets.yaml` + `secrets.yaml.example`).
- `services.authentik.forwardAuth` helper emits an nginx `auth_request` block
  against the outpost for no-native-login vhosts.

### Live deployment status (this session)
- [x] Stack deployed + healthy: `docker ps` shows all 4 containers healthy,
      `auth.bnuy.dev` via loopback serves the `/if/flow/initial-setup/` page.
- [x] Volume-permission fix: `media`/`custom-templates` owned uid 1000 (server
      runs as uid 1000; 500 on /templates → chown + tmpfiles `Z` re-assert).
- [ ] Admin bootstrap via the web UI (navigate to `https://auth.bnuy.dev/`,
      completes `/setup` flow) — interactive, left to operator.
- [ ] mailcow OAuth2/OIDC source in authentik (mailcow = IdP; live mailbox
      passwords) — the actual fix for adriannascarr sign-in. Needs the OAuth
      client registered in mailcow (`oauth_clients` table) + source config.
- [ ] Proxy provider + Outpost at 127.0.0.1:9000 (for nginx forward-auth).
- [ ] Attach `forwardAuth` to the headscale panel vhost + homepage mgmt group.
- [ ] Verify adriannascarr@bnuy.dev sign-in.

### ponytail notes
- Single docker compose stack on the compose bridge; the proxy outpost (created
  in authentik) will publish 9000 to loopback only so host nginx reaches it and
  nothing else. Server creds never in nix store (sops env at `up`).
