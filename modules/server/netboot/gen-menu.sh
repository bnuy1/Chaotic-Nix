#!/usr/bin/env bash
set -euo pipefail

ISO_DIR="${ISO_DIR:-/srv/iso}"
OUTPUT="${OUTPUT:-/srv/tftp/iso-menu.ipxe}"
LISTEN_IP="${LISTEN_IP:-$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}')}"
HTTPS_PORT="${HTTPS_PORT:-8443}"
PROTOCOL="${PROTOCOL:-https}"
TFTP_ROOT="${TFTP_ROOT:-/srv/tftp}"
ISO_FILES_DIR="${TFTP_ROOT}/iso-files"
_url_base="$LISTEN_IP"

for cmd in xorriso 7z bsdtar; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "gen-menu.sh: ERROR: $cmd not found. Install with: nix-shell -p xorriso p7zip libarchive" >&2
        exit 1
    fi
done

mkdir -p "$(dirname "$OUTPUT")" "$ISO_FILES_DIR" "$ISO_DIR/sysutils"/{hardware,recovery,antivirus}
rm -f "$OUTPUT"

extract_from_iso() {
    local iso=$1 src=$2 dst=$3
    if [ -s "$dst" ] && [ ! "$iso" -nt "$dst" ]; then
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    rm -f "$dst"
    # Try xorriso first (ISO 9660 / UDF)
    xorriso -indev "$iso" -osirrox on -extract "$src" "$dst" 2>/dev/null
    if [ -f "$dst" ] && [ -s "$dst" ]; then
        return 0
    fi
    # Fallback: 7z handles nested/El Torito images (sparse Win11 ISOs)
    # Use 'e' (extract without paths) so file lands at "$dst", not "dir/sources/boot.wim"
    rm -f "$dst"
    7z e "$iso" -o"$(dirname "$dst")" "${src#/}" -y 2>/dev/null
    if [ -f "$dst" ] && [ -s "$dst" ]; then
        return 0
    fi
    # Fallback: bsdtar (libarchive) handles many archive formats
    rm -f "$dst"
    bsdtar -xOf "$iso" "${src#/}" > "${dst}.tmp" 2>/dev/null && mv "${dst}.tmp" "$dst" || rm -f "${dst}.tmp"
    if [ -f "$dst" ] && [ -s "$dst" ]; then
        return 0
    fi
    return 1
}

find_in_iso() {
    local iso=$1 pattern=$2
    xorriso -indev "$iso" -find / -name "$pattern" -type f 2>/dev/null | head -1
}

is_windows_iso() {
    local iso=$1
    # Check for common Windows marker files visible in ISO 9660
    xorriso -indev "$iso" -find / -name "bootmgr" -type f 2>/dev/null | grep -q bootmgr && return 0
    xorriso -indev "$iso" -find / -name "bootmgfw.efi" -type f 2>/dev/null | grep -q bootmgfw.efi && return 0
    xorriso -indev "$iso" -find / -name "install.wim" -type f 2>/dev/null | grep -q install.wim && return 0
    # Check volume metadata for Microsoft
    xorriso -indev "$iso" -pvd_info 2>/dev/null | grep -qi "microsoft" && return 0
    return 1
}

is_nixos_iso() {
    local iso=$1
    xorriso -indev "$iso" -find / -name "nix-store.squashfs" -type f 2>/dev/null | grep -q nix-store.squashfs && return 0
    return 1
}

find_squashfs_in_iso() {
    local iso=$1
    local path
    path=$(find_in_iso "$iso" "filesystem.squashfs")
    [ -n "$path" ] && echo "$path" && return 0
    path=$(find_in_iso "$iso" "squashfs.img")
    [ -n "$path" ] && echo "$path" && return 0
    path=$(find_in_iso "$iso" "*.squashfs")
    [ -n "$path" ] && echo "$path" && return 0
    return 1
}

find_kernel_in_iso() {
    local iso=$1
    local path
    path=$(find_in_iso "$iso" "vmlinuz*")
    [ -n "$path" ] && echo "$path" && return 0
    path=$(find_in_iso "$iso" "bzImage")
    [ -n "$path" ] && echo "$path" && return 0
    return 1
}

write_boot_entry() {
    local iso=$1 item_name=$2 safe_name=$3 name=$4
    local iso_rel

    if is_windows_iso "$iso"; then
        extract_dir="${ISO_FILES_DIR}/${safe_name}"
        bootwim_path="${extract_dir}/boot.wim"
        bootmgr_path="${extract_dir}/bootmgr.efi"
        bcd_path="${extract_dir}/bcd"
        bootsdi_path="${extract_dir}/boot.sdi"

        for file_spec in "/sources/boot.wim:$bootwim_path" "/bootmgr.efi:$bootmgr_path" "/boot/bcd:$bcd_path" "/boot/boot.sdi:$bootsdi_path"; do
            src="${file_spec%%:*}"
            dst="${file_spec#*:}"
            if [ ! -f "$dst" ]; then
                echo "  Extracting: ${name} (${src})" >&2
                extract_from_iso "$iso" "$src" "$dst" 2>/dev/null || true
            fi
        done

        missing=0
        for f in "$bootwim_path" "$bootmgr_path" "$bcd_path" "$bootsdi_path"; do
            [ -f "$f" ] || missing=1
        done

        if [ "$missing" -eq 0 ]; then
            cat >> "$OUTPUT" << WIMENTRY
:${item_name}
echo Booting: ${name} (Windows via wimboot)
kernel ${PROTOCOL}://${_url_base}:${HTTPS_PORT}/wimboot
initrd ${PROTOCOL}://${_url_base}:${HTTPS_PORT}/iso-files/${safe_name}/bootmgr.efi bootmgr.efi
initrd ${PROTOCOL}://${_url_base}:${HTTPS_PORT}/iso-files/${safe_name}/bcd BCD
initrd ${PROTOCOL}://${_url_base}:${HTTPS_PORT}/iso-files/${safe_name}/boot.sdi boot.sdi
initrd ${PROTOCOL}://${_url_base}:${HTTPS_PORT}/iso-files/${safe_name}/boot.wim boot.wim
boot

WIMENTRY
        else
            iso_rel=$(echo "$iso" | sed "s|${ISO_DIR}/||" | sed 's/ /%20/g')
            cat >> "$OUTPUT" << SANENTRY
:${item_name}
echo Booting: ${name} (Windows - sanboot fallback)
sanboot "${PROTOCOL}://${_url_base}:${HTTPS_PORT}/iso/${iso_rel}"
echo Boot failed
prompt Press ENTER to return to menu
goto start

SANENTRY
        fi

    elif is_nixos_iso "$iso"; then
        init_path=""
        if [ -f "${TFTP_ROOT}/autoexec.ipxe" ]; then
            init_path=$(grep -oP 'init=[^ ]+' "${TFTP_ROOT}/autoexec.ipxe" | head -1)
        fi
        init_path="${init_path:-init=/init}"
        cat >> "$OUTPUT" << NIXOSENTRY
:${item_name}
echo Booting: ${name} (NixOS ISO - netboot kernel+initrd)
kernel ${PROTOCOL}://${_url_base}:${HTTPS_PORT}/nixos/bzImage ${init_path} console=tty0 loglevel=4
initrd ${PROTOCOL}://${_url_base}:${HTTPS_PORT}/nixos/initrd
boot

NIXOSENTRY

    else
        squashfs_path=$(find_squashfs_in_iso "$iso" || true)
        kernel_path=$(find_kernel_in_iso "$iso" || true)

        if [ -n "$squashfs_path" ] && [ -n "$kernel_path" ]; then
            echo "  Extracting: ${name} (kernel + squashfs)" >&2
            extract_from_iso "$iso" "$kernel_path" "${ISO_FILES_DIR}/${safe_name}/kernel"
            extract_from_iso "$iso" "$squashfs_path" "${ISO_FILES_DIR}/${safe_name}/root.squashfs"

            kernel_url="${PROTOCOL}://${_url_base}:${HTTPS_PORT}/iso-files/${safe_name}/kernel"
            squashfs_url="${PROTOCOL}://${_url_base}:${HTTPS_PORT}/iso-files/${safe_name}/root.squashfs"

            cat >> "$OUTPUT" << LINUXENTRY
:${item_name}
echo Booting: ${name} (Linux - wrapper initrd)
kernel ${kernel_url} squashfs_url=${squashfs_url} console=tty0
initrd ${PROTOCOL}://${_url_base}:${HTTPS_PORT}/wrapper-initrd.gz
boot

LINUXENTRY
        else
            # Try extracting EFI bootloader for UEFI utility ISOs (memtest, HW diag, etc.)
            efi_path="${ISO_FILES_DIR}/${safe_name}/bootx64.efi"
            if [ ! -s "$efi_path" ]; then
                echo "  Extracting: ${name} (EFI bootloader)" >&2
                extract_from_iso "$iso" "/efi/boot/bootx64.efi" "$efi_path" 2>/dev/null || true
            fi
            if [ -s "$efi_path" ]; then
                cat >> "$OUTPUT" << EFIENTRY
:${item_name}
echo Booting: ${name} (EFI chainload)
chain ${PROTOCOL}://${_url_base}:${HTTPS_PORT}/iso-files/${safe_name}/bootx64.efi || goto start

EFIENTRY
            else
                echo "  WARNING: ${name} - unrecognized ISO format; falling back to sanboot" >&2
                iso_rel=$(echo "$iso" | sed "s|${ISO_DIR}/||" | sed 's/ /%20/g')
                cat >> "$OUTPUT" << FALLBACK
:${item_name}
echo Booting: ${name} (sanboot fallback)
sanboot "${PROTOCOL}://${_url_base}:${HTTPS_PORT}/iso/${iso_rel}"
echo Boot failed
prompt Press ENTER to return to menu
goto start

FALLBACK
            fi
        fi
    fi
}

cat > "$OUTPUT" << PROLOGUE
#!ipxe
# Auto-generated by gen-menu.sh

:start
set menu-timeout 0
cpair --foreground 7 --background 4 0
cpair --foreground 7 --background 4 1
cpair --foreground 0 --background 7 2
cpair --foreground 6 --background 4 3

menu bnuy boot ISOs
item --gap --
PROLOGUE

count=0
for iso in "$ISO_DIR"/*.iso; do
    [ -f "$iso" ] || continue
    name=$(basename "$iso" .iso)
    item_name="iso_${name//[^a-zA-Z0-9_]/_}"
    display="${name:0:50}"

    type=""
    label=""
    if is_windows_iso "$iso"; then
        type="windows"
        label=" [Windows]"
    elif is_nixos_iso "$iso"; then
        type="nixos"
        label=" [NixOS]"
    elif find_squashfs_in_iso "$iso" >/dev/null 2>&1; then
        type="linux"
        label=" [Linux]"
    else
        type="unknown"
        label=" [?]"
    fi

    item_index=$((count + 1))
    if [ "$count" -lt 9 ]; then
        key=$item_index
        echo "item --key ${key} ${item_name}    [${item_index}] ${display}${label}" >> "$OUTPUT"
    else
        echo "item ${item_name}    ${display}${label}" >> "$OUTPUT"
    fi
    count=$((count + 1))
done

if [ "$count" -eq 0 ]; then
    echo "item --gap --    (no ISOs found in ${ISO_DIR})" >> "$OUTPUT"
fi

# Gap line and back item
echo "item --gap --     ----------------------------------------" >> "$OUTPUT"
echo "item --key b back     [b] <-- Back to Main Menu" >> "$OUTPUT"
echo "choose selected || goto back" >> "$OUTPUT"
echo "goto \${selected}" >> "$OUTPUT"
echo "" >> "$OUTPUT"

if [ "$count" -gt 0 ]; then
    for iso in "$ISO_DIR"/*.iso; do
        [ -f "$iso" ] || continue
        name=$(basename "$iso" .iso)
        item_name="iso_${name//[^a-zA-Z0-9_]/_}"
        safe_name="${name//[^a-zA-Z0-9_-]/_}"
        write_boot_entry "$iso" "$item_name" "$safe_name" "$name"
    done
fi

cat >> "$OUTPUT" << BACK
:back
exit
BACK

echo "gen-menu.sh: wrote ${count} ISO entr${count} to ${OUTPUT}"

# ========== Sysutils submenu ==========
sys_root="${ISO_DIR}/sysutils"
if [ -d "$sys_root" ]; then
    SYSOUTPUT="${TFTP_ROOT}/sysutils.ipxe"
    OUTPUT="$SYSOUTPUT"
    rm -f "$OUTPUT"

    cat > "$OUTPUT" << SYSPROLOGUE
#!ipxe
# Auto-generated by gen-menu.sh

:start
set menu-timeout 0
cpair --foreground 7 --background 4 0
cpair --foreground 7 --background 4 1
cpair --foreground 0 --background 7 2
cpair --foreground 6 --background 4 3

menu Sysutils
SYSPROLOGUE

    sys_count=0
    for cat_dir in "$sys_root"/*/; do
        [ -d "$cat_dir" ] || continue
        category=$(basename "$cat_dir")

        # Check for ISOs in this directory
        has_isos=0
        for iso in "$cat_dir"/*.iso; do
            [ -f "$iso" ] && has_isos=1 && break
        done
        [ "$has_isos" -eq 0 ] && continue

        echo "item --gap --" >> "$OUTPUT"
        echo "item --gap --     ============ ${category} ============" >> "$OUTPUT"
        echo "item --gap --" >> "$OUTPUT"

        for iso in "$cat_dir"/*.iso; do
            [ -f "$iso" ] || continue
            name=$(basename "$iso" .iso)
            item_name="sys_${category}_${name//[^a-zA-Z0-9_]/_}"
            safe_name="sysutils_${category}_${name//[^a-zA-Z0-9_-]/_}"
            display="${name:0:50}"

            label=""
            if is_windows_iso "$iso"; then
                label=" [Windows]"
            elif is_nixos_iso "$iso"; then
                label=" [NixOS]"
            elif find_squashfs_in_iso "$iso" >/dev/null 2>&1; then
                label=" [Linux]"
            fi

            sys_count=$((sys_count + 1))
            if [ "$sys_count" -lt 10 ]; then
                echo "item --key ${sys_count} ${item_name}    [${sys_count}] ${display}${label}" >> "$OUTPUT"
            else
                echo "item ${item_name}    ${display}${label}" >> "$OUTPUT"
            fi
        done
    done

    if [ "$sys_count" -eq 0 ]; then
        echo "item --gap --    (no sysutils ISOs found)" >> "$OUTPUT"
    fi

    echo "item --gap --" >> "$OUTPUT"
    echo "item --key b back     [b] <-- Back to Main Menu" >> "$OUTPUT"
    echo "choose selected || goto back" >> "$OUTPUT"
    echo "goto \${selected}" >> "$OUTPUT"
    echo "" >> "$OUTPUT"

    if [ "$sys_count" -gt 0 ]; then
        for cat_dir in "$sys_root"/*/; do
            [ -d "$cat_dir" ] || continue
            for iso in "$cat_dir"/*.iso; do
                [ -f "$iso" ] || continue
                name=$(basename "$iso" .iso)
                category=$(basename "$(dirname "$iso")")
                item_name="sys_${category}_${name//[^a-zA-Z0-9_]/_}"
                safe_name="sysutils_${category}_${name//[^a-zA-Z0-9_-]/_}"
                write_boot_entry "$iso" "$item_name" "$safe_name" "$name"
            done
        done
    fi

    cat >> "$OUTPUT" << SYSBACK
:back
exit
SYSBACK

    if [ "$sys_count" -gt 0 ]; then
        echo "gen-menu.sh: wrote ${sys_count} sysutils entr${sys_count} to ${SYSOUTPUT}"
    fi
fi
