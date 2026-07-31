<div align="center">
  <h1>Bnuy's nix</h1>
  <h3></h3>
</div>

<div align="center">

![](https://img.shields.io/github/last-commit/bnuy1/bnuynix?style=for-the-badge&logo=git&logoColor=D9E0EE&labelColor=1E202B&color=8ad7eb)
<a href="https://discord.gg/nCJrkFB6qT">
<img alt="Dynamic JSON Badge" src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fdiscordapp.com%2Fapi%2Finvites%2FnCJrkFB6qT%3Fwith_counts%3Dtrue&query=approximate_member_count&style=for-the-badge&logo=discord&logoColor=D9E0EE&label=discord&labelColor=%231E202B&color=86dbc0&link=https%3A%2F%2Fdiscord.gg%2FnCJrkFB6qT">
</a>
![GitHub repo size](https://img.shields.io/github/repo-size/bnuy1/bnuynix?style=for-the-badge&logo=protondrive&logoColor=8ad7eb&label=SIZE&labelColor=1E202B&color=8ad7eb)

</div>

A multi-host NixOS flake managing four machines -- desktop, laptop, server, and a fallback template.

---

## Quick Start

```
git clone https://github.com/bnuy1/bnuynix /etc/nixos
```

The flake auto-discovers hosts by scanning `hosts/` for folders containing a `variables.nix` file. Each folder becomes a build target matching its folder name.

**Build for your machine:**

```bash
# To get started use this command:
sudo nixos-rebuild switch --flake /etc/nixos#<your-hostname>

# if your current networking hostname matches a given hostname folder then use this:
sudo nixos-rebuild switch
# OR
nrs # which is a alias for the command above

# Its worth noting that after your setup, any changes can subsiquently
# use the two commands above rather than the wordy --flake one
```

If no folder matches the target hostname, it falls back to `hosts/default/`.

If you want to force a specific host config for all builds, set `manualHostname` in `flake.nix`:

```nix
manualHostname = "Hostname-String-Name";
```

<details>
  <summary>Adding your own machine</summary>

Create `hosts/<your-hostname>/variables.nix` using `hosts/default/variables.nix` as a reference. This file controls:

- Users and their home-manager config (shell, git, ssh keys, extra packages)
- Display manager (SDDM, LY, TUI) and graphical vs headless mode
- GPU drivers (Intel, AMD, NVIDIA, or combinations)
- Kernel selection (zen, xanmod, stable, lts)
- Services to enable (Docker, printing, bluetooth, Steam, etc.)
- Networking (SSH port, fail2ban, firewall rules)
- Power management (suspend, hibernate, TLP vs power-profiles-daemon)

Every variable has a default, so you generally need to override what differs from stock.

</details>

<details>
  <summary>Secrets (SOPS)</summary>
    SOPS are currently only development package specific, if you need to mess with my development folder, here be dragons. there is a reason its not imported by default. 
    also they are just plain difficult to work with and only exist for hypr specific needs.

</details>

---

## Structure

```
.
├── flake.nix
├── configuration.nix
├── hosts/
│   ├── commonhostpackages.nix
│   ├── antimatter/       # AMD desktop -- Zen, ROCm, Ollama
│   ├── nebula/           # T440p laptop -- Xanmod, LUKS+btrfs, hardened
│   ├── singularity/      # Headless server -- Xanmod, hardened, Docker
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
│   │   ├── powermanagement.nix
│   │   ├── polkit.nix
│   │   └── xwaylandvideobridge/ # HA it barely works (if at all!)
│   ├── home/             # homemanager configs
│   │   ├── commonuserpackages.nix
│   │   ├── kitty.nix
│   │   ├── stylix.nix
│   │   ├── hyprland/
│   │   └── nixvim/       # Peruser neovim
│   ├── hardware/
│   │   ├── antimatter.nix
│   │   ├── t440p.nix
│   │   └── gpu/          # auto switching gpu selection and drivers too!
│   └── development/      # Stay out unless you know what your doing, they wont harm you if you dont touch it
│       ├── minecraftserver/
│       ├── matrix/
│       └── t440p/
└── assets/
    ├── wallpapers/
    └── grubtheme/
```

---

## License

This project is licensed under the GPL-3 license.

```
[1] Anyone can copy, modify and distribute this software.
[2] You have to include the license and copyright notice with each and every distribution.
[3] You can use this software privately.
[4] You can use this software for commercial purposes.
[5] If you dare build your business solely from this code, you risk open-sourcing the whole code base.
[6] If you modify it, you have to indicate changes made to the code.
[7] Any modifications of this code base MUST be distributed with the same license, GPLv3.
[8] This software is provided without warranty.
[9] The software author or license can not be held liable for any damages inflicted by the software.
```
