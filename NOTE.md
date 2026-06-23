# System Issues & Repo Architecture

Generated from `journalctl -b` analysis on 2026-06-22.
Host: `antimatter` (Z790 AORUS PRO X, Intel, AMD GPU, zen kernel)

---

## REPOSITORY ARCHITECTURE

This is a multi-host NixOS flake (`/etc/nixos`). Key structural points:

### Flake / Host Discovery
- `flake.nix` auto-discovers hosts from folders under `hosts/` that contain `variables.nix`
- Current hosts: `default` (fallback template), `antimatter`, `nebula` (T440p laptop), `singularity` (headless server)
- **`manualHostname = "antimatter"`** is set in flake.nix:34 — this overrides ALL build targets. Set to `null` to build per-host.
- Host vars merge: `hosts/default/variables.nix` is base, host-specific `variables.nix` is merged on top via `recursiveUpdate`
- Module path: `configuration.nix` → imports `modules/core/` + `hosts/${host}/` + `modules/development/minecraft-server/`

### Secrets Data Flow (sops-nix)
Encrypted in `development/minecraft-server/secrets.yaml` → decrypted by `sops-nix` (activation script) using SSH age key → written as files under `/run/secrets/` → injected into Docker containers via `environmentFiles`. Also read by `mysql-create-fish-user` service and `bnuy-rollback` script.

### Key Dirs
- `modules/core/` — system config (networking, boot, swap, displayManager, hyprland, etc.)
- `modules/hardware/` — machine-specific hardware configs
- `modules/home/` — home-manager user configs (hyprland, kitty, waybar, nixvim, etc.)
- `modules/development/` — minecraft-server, matrix, t440p tools
- `hosts/` — per-host variables, packages, hardware configs
- `assets/` — wallpapers, server icons, GRUB theme

---

## LUKS / ENCRYPTION

### 1. LUKS Swap Device Times Out (90s boot delay)
- **UUID**: `luks-d6569e19-e6ed-4336-90b6-8be1b871fdce`
- **Log**: `Timed out waiting for device /dev/mapper/luks-d6569e19-e6ed-4336-90b6-8be1b871fdce`
- **Effect**: `swap.target` fails (but zram swap still works); adds ~90s to boot.
- **Root cause**: `hardware-configuration.nix:42` defines this as a swap device, but it's a LUKS container with no way to provide its passphrase at boot. Unlike the root LUKS device (which gets a tty1 prompt), the swap LUKS has no interactive prompt and no keyfile configured.
- **Fix options**:
  a. **Remove it** (simplest): zram is already enabled with 100% RAM. The LUKS swap is redundant. Delete the `swapDevices` entry from `hardware-configuration.nix` and regenerate.
  b. **Add a keyfile**: Generate a random key, add it to the LUKS slot, and reference it in `boot.initrd.luks.devices."luks-...".keyFile`. This keeps disk encryption on swap.
  c. **TPM2 unlock**: Use `systemd-cryptenroll` to bind the swap LUKS to the TPM2, allowing auto-unlock at boot.

### 2. Root LUKS Decrypt is Slow (27s wall, 6s CPU)
- **Log**: `Set cipher aes, mode xts-plain64, key size 512 bits`
- **Analysis**: XTS mode splits the key in half: AES-512 means AES-256 for encryption + AES-256 for the tweak key. AES-256 for the tweak provides zero additional security over AES-128 for the tweak — the XTS mode security bound is already reached with a 256-bit key (AES-128 + AES-128).
- **Is AES-256 more secure?** For XTS mode, **no**. A 256-bit XTS key (AES-128 per component) provides 128 bits of security, which is far beyond any practical attack. The 512-bit key just means your CPU does ~2x the AES rounds for each block, which is pure throughput loss with no security gain. AES-128 remains unbroken in any practical sense.
- **Fix**: Re-encrypt the LUKS container with a 256-bit key:
  ```bash
  # Add a 256-bit key slot (this doesn't change the master key, just how it's stored)
  cryptsetup luksChangeKey --key-size 256 /dev/disk/by-uuid/e54583d6-...
  # Or fully re-encrypt (requires offlining the device):
  cryptsetup reencrypt --encrypt --reduce-device-size 32M --key-size 256 /dev/disk/by-uuid/e54583d6-...
  ```

### 3. TPM Device Timeouts (~27.6s each)
- **Log**: `dev-tpmrm0.device`, `dev-tpm0.device`, `ttyS[0-3].device` in `systemd-analyze blame`
- **Cause**: systemd waits for TPM1.0/2.0 + legacy serial port devices that are slow to probe or unavailable.
- **Fix**: Add to `boot.kernelParams` in `boot.nix:26`:
  ```nix
  "tpm_tis.interrupts=0"  # Skips waiting for TPM interrupts
  ```
  Or mask the devices in systemd:
  ```nix
  systemd.masks = [ "dev-tpmrm0.device" "dev-tpm0.device" "dev-ttyS0.device" "dev-ttyS1.device" "dev-ttyS2.device" "dev-ttyS3.device" ];
  ```

---

## SECRETS / CREDENTIAL MANAGEMENT

### 4. sops-nix.keyfile Missing (CRITICAL — Blocks all minecraft servers)
- **Logs**:
  - `sops-install-secrets: cannot read keyfile '/var/lib/sops-nix/key.txt': no such file or directory`
  - `Activation script snippet 'setupSecrets' failed (1)`
  - `docker: --env-file: open /run/secrets/minecraft_env: no such file or directory`
  - `mysql-create-fish-user.service: cat: /run/secrets/minecraft/MYSQL_PASSWORD: No such file or directory`
- **Root cause**: `secrets.nix:8` sets `sops.age.keyFile = "/var/lib/sops-nix/key.txt";` but this path **never existed**. On the user's old machine, it was probably created manually. Since it's an absolute path outside the nix store, it's not tracked in git and wasn't created on this new machine.
- **Irony**: The SSH host key import actually works (`sops-install-secrets: Imported /etc/ssh/ssh_host_ed25519_key as age key`), but the missing `keyFile` override takes precedence and breaks everything.
- **Cascade failure**:
  ```
  sops.age.keyFile points to missing /var/lib/sops-nix/key.txt
  → sops-nix activation fails ("setupSecrets" snippet errors)
  → /run/secrets/minecraft_env never created
  → All 5 Docker containers (velocity, survival, lab, creative, raina) fail with "no such file"
  → /run/secrets/minecraft/MYSQL_PASSWORD never created
  → mysql-create-fish-user.service fails
  → mc-backup service has no secrets
  ```
- **Fix options**:
  a. **Remove `sops.age.keyFile`** (recommended): Delete line 8 from `secrets.nix`. The SSH host key is already imported and working as an age key. This is the cleanest fix.
  b. **Create the key file manually**: `sudo mkdir -p /var/lib/sops-nix && sudo age-keygen -o /var/lib/sops-nix/key.txt`, then add the public key to `secrets.yaml`'s age recipients. Requires `sudo` + manual step + git tracking of the age pubkey.

### 5. sops-nix.service Misconfigured (Empty Unit)
- **Log**: `sops-nix.service: Service has no ExecStart=, ExecStop=, or SuccessAction=. Refusing.`
- **Root cause**: `secrets.nix:4` has `systemd.services.sops-nix.enable = true;` which creates a systemd unit with nothing to run. The sops-nix module from flake inputs already handles secret deployment via the activation script — this manual `enable` creates a competing empty unit.
- **Fix**: Delete line 4 from `secrets.nix`. The `inputs.sops-nix.nixosModules.sops` import in `flake.nix:84` already provides the correct service.

### 6. gnome-keyring / Secret Service Race with SDDM
- **Logs**:
  - `gkr-pam: unable to locate daemon control file` (3x during SDDM login)
  - `gkr-pam: stashed password to try later in open session`
  - Eventually: `gnome-keyring-daemon started properly and unlocked keyring` (on 3rd attempt)
- **Root cause**: `sddm.nix:8-9` configures gnome-keyring like this:
  ```nix
  services.gnome.gnome-keyring.enable = dm.name == "sddm";
  security.pam.services.hyprland.enableGnomeKeyring = dm.name == "sddm";
  ```
  This wires gnome-keyring into **Hyprland's** PAM service — but authentication flows through **SDDM's** PAM service, not Hyprland's. When SDDM's PAM stack tries to call `pam_gnome_keyring.so`, there's no `auto_start` configured, so it can't spawn the daemon. It stashes the password and retries on subsequent PAM calls. By the 3rd attempt, the user-level `gnome-keyring-daemon` (started by `hyprland.conf` via `exec-once`) is finally running.
- **Effect**: First 1-2 login attempts silently fail (or take multiple tries). The login keyring never unlocks on first attempt.
- **Fix**: Add a line to `sddm.nix`:
  ```nix
  security.pam.services.sddm.enableGnomeKeyring = dm.name == "sddm";
  ```
  This adds `pam_gnome_keyring.so auto_start` to SDDM's auth stack, which spawns the daemon and unlocks the login keyring with the password the user just typed — before the session even starts.

### 7. Duplicate DBus Secret Service Registrations
- **Log**: Multiple `Ignoring duplicate name 'org.freedesktop.secrets'` messages
- **Cause**: Both `gnome-keyring` and `xdg-desktop-portal` ship `org.freedesktop.secrets` service files. They get merged from system-path + gnome-keyring + flatpak store paths.
- **Effect**: Harmless (just noisy DBus broker warnings), but could cause subtle issues if the wrong secret service provider answers a request.

---

## NETWORK / NETWORKMANAGER

### 8. NetworkManager IPv4 Forwarding Error
- **Log**: `NetworkManager: error setting IPv4 forwarding to '1': Resource temporarily unavailable`
- **Cause**: NM tries to set `net.ipv4.ip_forward=1` but the sysctl is busy (maybe another process holds a lock). This happens on both wifi devices (`/net/connman/iwd/0` and `/net/connman/iwd/1`).
- **Fix**: Either set it explicitly in `networking.nix`:
  ```nix
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  ```
  Or if forwarding is not needed, NM won't retry and this remains a harmless warning.

### 9. WiFi (ath12k) Driver Crashes / Connection Failures
- **Logs**: 
  - `ath12k_wifi7_pci: qmi dma allocation failed (7274496 B type 1)`
  - `ath12k: WARNING at mac.c:12168` (double-free in `ath12k_mac_op_unassign_vif_chanctx`)
  - `iwd: unable to move link sta from state 0 to 1`
  - `NetworkManager: Activation: failed for connection '<unknown>'`
- **Root cause**: The Qualcomm ath12k WiFi 7 driver on the zen kernel is buggy:
  1. QMI DMA allocation fails (tries 7MB, falls back to smaller)
  2. Station state machine transitions fail (can't move from state 0 to 1)
  3. Double-free/use-after-free in channel context management (kernel WARNING at mac.c:12168)
  4. Stack trace shows `ieee80211_prep_connection` → `cfg80211_connect` → `nl80211_connect`
- **Effect**: wlan1 cannot associate with any AP. Both IWD and NM fail.
- **Fix options**:
  a. **Switch to stable/lts kernel**: Change `kernel = "zen"` to `kernel = "stable"` in `hosts/antimatter/variables.nix:3`. The mainline kernel may have a more stable ath12k driver.
  b. **Update firmware**: Ensure `hardware.enableRedistributableFirmware = true` (already set in `system.nix`) and check if `linux-firmware` has the latest ath12k firmware.
  c. **Use IWD without NM**: Try configuring IWD directly via `networking.wireless.iwd.settings` to bypass NM's connection management.
  d. **Hardware workaround**: If the Qualcomm card is defective, use a USB WiFi dongle (Intel AX210 is well-supported).

### 10. Dual mDNS Stacks
- **Log**: `avahi-daemon: WARNING: Detected another IPv4 mDNS stack running on this host`
- **Cause**: `services.resolved.enable = true` (in `networking.nix`) and `services.avahi.enable = true` (in `printing.nix`) both run mDNS responders.
- **Fix**: Disable avahi (if not needed for printer discovery) or disable resolved's mDNS via:
  ```nix
  services.resolved.enable = true;
  services.avahi.enable = false;  # If printers support DNS-SD without avahi
  ```

---

## DOCKER

### 11. All Minecraft Containers Fail at Boot (Secrets Cascade)
- **Log**: `docker: --env-file: open /run/secrets/minecraft_env: no such file or directory` (velocity, survival, creative, raina startup scripts)
- **Root cause**: sops-nix fails to deploy secrets (issue #4). All containers reference `config.sops.secrets."minecraft_env".path` via `environmentFiles`, which points at paths under `/run/secrets/` that never get created.
- **Fix**: Fix sops-nix key issue (#4) first. Containers will then start automatically.

### 12. Rootless Docker Fails Repeatedly
- **Log**: `docker.service (rootless): Failed with result 'exit-code'` (4 attempts)
- **Cause**: The rootless Docker service exits before completing initialization. May cascade from cgroup issues, missing `newuidmap`/`newgidmap`, or general Docker daemon crash.
- **Fix**: Check `/home/bnuy/.local/share/docker/` and systemd user logs for the rootless service. May need `boot.enableContainers = false` or additional rootless prerequisites.

### 13. Deprecated Systemd Directive
- **Log**: `/etc/systemd/system/docker-minecraft-*.service: Unknown key 'StartLimitIntervalSec' in section [Service], ignoring.`
- **Cause**: `StartLimitIntervalSec` was renamed to `StartLimitInterval` in systemd 250+. The minecraft-server.nix service overrides use the old name at line 541/562/583/605.
- **Fix**: Replace `StartLimitIntervalSec` with `StartLimitInterval` in all 4 service overrides in `minecraft-server.nix`.

---

## HARDWARE / GRAPHICS

### 14. AMDGPU Color Management Failures
- **Log**: `(EE) AMDGPU(0): Failed to initialize color management property DEGAMMA_LUT on CRTC[0-3]`
- **Cause**: Xorg amdgpu driver can't set degamma LUT properties on RX 7000 series. Likely a kernel/Xorg version mismatch.
- **Fix**: Harmless unless color-accurate work is needed. Try newer xf86-video-amdgpu or switch to Wayland (already using Hyprland, but Xorg is started by SDDM).

### 15. AMDGPU Vendor Infoframe Error
- **Log**: `amdgpu: Failed to setup vendor infoframe on connector DP-3: -22`
- **Cause**: Invalid parameter (-EINVAL) when writing DisplayPort vendor infoframe. May affect HDR or display identification on that DP port.
- **Fix**: Check DisplayPort cable on that monitor. Try a different cable or port.

---

## BLUETOOTH

### 16. BAP/ISO Socket Not Supported
- **Logs**:
  - `BAP requires ISO Socket which is not enabled` (for hci0 and hci1)
  - `RFCOMM server failed for Message Notification/Message Access/Phone Book Access/File Transfer/Object Push/Hands-Free`
- **Cause**: The Bluetooth controllers don't support LE Audio (BAP) and RFCOMM is not available. The kernel may lack `CONFIG_BT_ISO`.
- **Fix**: If hardware supports it, ensure `CONFIG_BT_ISO=y` in the kernel (zen kernel = `linuxPackages_zen` may have it disabled). Otherwise these are harmless.

---

## SMALL / CLEANUP

### 17. Miscellaneous
- **nft not found**: `dockerd: Deleting nftables IPv4 rules error: "nft" not in $PATH` — Docker can't clean nftables rules. Add `nftables` to `environment.systemPackages` or add `"iptables": [ "-j", "NFLOG" ]` docker daemon config.
- **Ollama DNS failures**: `lookup ollama.com: no such host` — Ollama starts before network is online. Add to ollama config: `after = [ "network-online.target" ]; wants = [ "network-online.target" ];`
- **SDDM missing assets**: `Cannot open: angle-down.png` in SDDM combobox — Theme asset missing from SDDM package (known upstream issue).
- **X11 socket lock warning**: `Opening file "/tmp/.X11-unix/X0_" failed` — tmpfiles runs before X11 tmpfs is mounted. Harmless.
- **ACPI/HPET**: `hpet_acpi_add: no address or irqs in _CRS` — Firmware bug, harmless.

---

## SUMMARY OF FIXES

| Priority | File(s) to Edit | Change | Impact |
|----------|-----------------|--------|--------|
| 🔴 High | `minecraft-server/secrets.nix:4` | Delete `systemd.services.sops-nix.enable = true;` | Fixes empty sops-nix.service |
| 🔴 High | `minecraft-server/secrets.nix:8` | Delete `sops.age.keyFile` line (use SSH key only) | Unlocks ALL minecraft servers, MySQL, backups |
| 🔴 High | `hosts/antimatter/hardware-configuration.nix:42-43` | Remove swapDevices entry for LUKS swap | Removes 90s boot timeout |
| 🟡 Medium | `core/displayManager/sddm.nix` | Add `security.pam.services.sddm.enableGnomeKeyring = ...` | Fixes login keyring unlock on first attempt |
| 🟡 Medium | `hosts/antimatter/variables.nix:3` | Change `kernel = "zen"` to `"stable"` | Fixes ath12k WiFi crashes |
| 🟡 Medium | `minecraft-server/minecraft-server.nix:541,562,583,605` | `StartLimitIntervalSec` → `StartLimitInterval` | Removes systemd warnings |
| 🟢 Low | `core/boot.nix:26` | Add `tpm_tis.interrupts=0` or mask TPM/serial devices | Saves ~55s boot time |
| 🟢 Low | `core/networking.nix` | Add `boot.kernel.sysctl."net.ipv4.ip_forward" = 1;` | Suppresses NM warnings |
| 🟢 Low | `core/networking.nix` or `core/printing.nix` | Disable avahi or resolved mDNS | Reliable .local resolution |

**Fix ordering note**: Fix #4 and #5 (sops-nix) first, then rebuild and reboot. All minecraft containers should start automatically after secrets are working. Then tackle the LUKS swap issue for boot speed.
