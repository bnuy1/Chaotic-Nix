<div align="center">
    <h1> bnuy-nix </h1>
    <h3>agnostic multi-host NixOS flake</h3>
</div>

<div align="center">

![GitHub last commit](https://img.shields.io/github/last-commit/bnuy1/bnuy-nix?style=for-the-badge&logo=git&logoColor=D9E0EE&labelColor=1E202B&color=8ad7eb)
![GitHub repo size](https://img.shields.io/github/repo-size/bnuy1/bnuy-nix?style=for-the-badge&logo=protondrive&logoColor=8ad7eb&label=SIZE&labelColor=1E202B&color=8ad7eb)
![NixOS](https://img.shields.io/badge/NixOS-25.11-8ad7eb?style=for-the-badge&logo=nixos&logoColor=D9E0EE&labelColor=1E202B)

</div>

NixOS configuration for my personal machines — a desktop, a laptop, and a headless server. Designed to be host-agnostic: drop in a new host folder and the flake auto-discovers it. Falls back gracefully when a hostname doesn't match a known folder.

---

## Hosts

| Host            | Role                  | Kernel | Display         | Users       | Key Features                                             |
| --------------- | --------------------- | ------ | --------------- | ----------- | -------------------------------------------------------- |
| **antimatter**  | Main desktop          | Zen    | SDDM / Hyprland | fur3, raina | AMD GPU + ROCm, Ollama, Docker, Libvirt, Steam, Sunshine |
| **nebula**      | ThinkPad T440p laptop | Xanmod | SDDM / Hyprland | fur3        | Intel GPU, LUKS + btrfs, hibernation, kernel hardening   |
| **singularity** | Headless server       | Xanmod | TUI (none)      | fur3        | Docker, kernel hardening, Minecraft servers, Matrix      |
| **default**     | Fallback template     | Stable | SDDM / Hyprland | fur3, raina | Generic config with placeholder UUIDs                    |

## Structure

```
.
├── flake.nix
├── configuration.nix
├── hosts/
│   ├── common-host-packages.nix
│   ├── antimatter/       # AMD desktop — Zen, ROCm, Ollama
│   ├── nebula/           # T440p laptop — Xanmod, LUKS+btrfs, hardened
│   ├── singularity/      # Headless server — Xanmod, hardened, Docker
│   └── default/          # Most likely.. your machine, its a fallback
├── modules/
│   ├── core/             # system core
│   │   ├── boot.nix      # Kernals and startup
│   │   ├── system.nix
│   │   ├── networking.nix
│   │   ├── home_manager.nix # controls the home/ directory and is where most of your changes will prob be
│   │   ├── hyprland.nix
│   │   ├── stylix.nix       # pretty colors
│   │   ├── virtualisation.nix
│   │   ├── steam.nix
│   │   ├── printing.nix
│   │   ├── swap.nix
│   │   ├── power-management.nix
│   │   ├── polkit.nix
│   │   └── xwaylandvideobridge/ # HA it barely works (if at all!)
│   ├── home/             # home-manager configs
│   │   ├── common-user-packages.nix
│   │   ├── kitty.nix
│   │   ├── stylix.nix
│   │   ├── noctalia.nix    # my bar/shell and i hate it
│   │   ├── hyprland/
│   │   └── nixvim/       # Per-user neovim
│   ├── hardware/
│   │   ├── antimatter.nix
│   │   ├── t440p.nix
│   │   └── gpu/          # auto switching gpu selection and drivers too!
│   └── development/      # Stay out unless you know what your doing, they wont harm you if you dont touch it
│       ├── minecraft-server/
│       ├── matrix/
│       └── t440p/
└── assets/
    ├── wallpapers/
    └── grub-theme/
```

## Usage

```bash
# Switch to this flake (run on the target machine)
sudo nixos-rebuild switch --flake .#hostname

# Faster rebuild with nh
nh os switch --flake .#hostname

# this also works!
nrs

# Force a specific host config regardless of real hostname
# → Set manualHostname in flake.nix to the folder name

# Update all flake inputs
nix flake update
```

## Features

- **Dynamic host discovery** — reads `hosts/` subdirectories at eval time; unknown hostnames fall back to `hosts/default/`. No hardcoded host list.
- **Per-host variables** — each host has a `variables.nix` acting as a registry. Shared modules consume these via conditional logic. Reduces duplication.
- **Selective unfree** — `allowUnfreePredicate` for granular per-package allowlisting instead of a global blank check.
- **Conditional graphical stack** — GUI modules (Hyprland, Steam, portals) gate on `displayManager == "sddm"`. Set it to `null` for headless.
- **Secrets** — SOPS + `sops-nix` with Age encryption for Minecraft credentials and SSH keys.

## Experimental Services

The `modules/development/` directory contains self-hosted services I run on my server (singularity):

- **Minecraft server cluster** — Velocity proxy + 4 Paper servers (survival, lab, creative, raina) + GeyserMC (Bedrock support) + Restic backups
- **Matrix chat** — Continuwuity server at chat.bnuy.dev + Coturn TURN

These are **personal experiments**. They won't deploy cleanly on your machine without tinkering — they depend on my specific directory layout, secrets, and networking. I plan to extract each into its own repository eventually.

## License

This project is licensed under the MIT license.

```
[x] Use, bolth public and private
[x] Modification
[x] Distribution
[x] Sublicensing
[x] Add additional restrictions
[ ] Remove Copyright Notice
[ ] Hold liable
```
