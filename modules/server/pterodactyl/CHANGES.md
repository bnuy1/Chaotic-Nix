# MC Network Change Log

Server: Pterodactyl/Wings on NixOS. Velocity proxy `a3f70d61`, Lobby `fd255e51` (Folia 26.2-5), Survival `88f35865`, Creative `b4eaaa4d`. MariaDB container `minecraft-db`.

## 2026-08-20 — Lobby shop dialog fixed (FancyDialogs Folia patch)

**Symptom:** Clicking the shopkeeper's "Can i see your wares?" button kicked the player with "Internal Exception". Other buttons (messages, open_dialog) worked.

**Root cause (2 bugs):**
1. Folia disables the entire Bukkit scheduler — `CraftScheduler.handle()` throws `UnsupportedOperationException` unconditionally. FancyDialogs' command actions called `Bukkit.getScheduler().runTask()` from inside the netty decoder thread → `DecoderException` → kick.
2. After fixing #1, dispatch still failed silently: `shopkeep.json` uses `"data": "/shop"` but `Player.performCommand()` requires no leading slash.

**Fix:** Patched two classes inside `plugins/FancyDialogs-1.3.0.jar`:
- `com/fancyinnovations/fancydialogs/actions/defaultActions/PlayerCommandDialogAction.class` — now runs via `player.getScheduler().run(plugin, task -> player.performCommand(cmd), null)` (EntityScheduler = player's region thread) and strips leading `/`.
- `.../ConsoleCommandDialogAction.class` — now uses `Bukkit.getGlobalRegionScheduler().execute(...)`.

Patch sources: `/tmp/nix-shell-1195571-2003148736/opencode/fdpatch/src/` (rebuild: `javac --release 21 -cp <folia-api>:<adventure-api>:<adventure-key>:<examination-api>`, then `jar -uf`). Original jar backup: `/tmp/.../FancyDialogs-1.3.0.jar.orig`.

Compile classpath jars live in `/games/pterodactyl/fd255e51-fba9-4a28-8b30-9b08f7959c6c/libraries/` (`dev/folia/folia-api/26.2.build.5-beta/`, `net/kyori/adventure-*`).

Note: FancyDialogs payload keys are only `dialog_id`, `button_id`, numeric args — dialog JSON commands must not rely on placeholder replacement beyond that.

**Status:** WORKING. Shop GUI opens from dialog button.

## 2026-08-20 — Green-rank chat color (FlectonePulse)

- Installed FlectonePulse 1.12.2 on Lobby, enabled in config.yml.
- Chat formats in `plugins/FlectonePulse/localizations/en_us.yml` (~line 663) prepended `<prefix>` to local + global formats so LuckPerms group prefixes (e.g. raw legacy `&a` for green rank) render.
- Reloaded via rcon. **Pending user verification of green chat.**

## 2026-08-20 — Diagnostics (temporary)

- Built + installed `KickTrace-0.1.0.jar` (netty pipeline hook attempt). Its own join handler throws UOE via CraftScheduler — harmless ERROR spam per join. **Remove when convenient** (delete jar + restart).
- `[fdpatch] dispatching/result` INFO lines per dialog-command click are left in intentionally; strip from PlayerCommandDialogAction if noise matters.

## Earlier (this session)

- SOPS secrets wired into pterodactyl.nix (`secrets.yaml`, `.example` committed).
- Declarative leaderboard + auto-rank: `leaderboard-update.sh` + systemd timer, verified live against MariaDB.
- Geyser: UDP 19132 allocated to Survival for Bedrock clients.
- Git changes staged but NOT committed.

## Ops notes

- Lobby restart ≈ 150–200 s (`Done (13x s)`).
- rcon: `docker exec fd255e51-fba9-4a28-8b30-9b08f7959c6c rcon-cli "<cmd>"`.
- EconomyShopGUI console can't open shops for players; `/shop <section>` is player-only context. Sections live in `plugins/EconomyShopGUI/sections/*.yml`.
- Transient watchdog stack traces during startup (region thread stuck on chunk file I/O) are one-offs, not actionable.
