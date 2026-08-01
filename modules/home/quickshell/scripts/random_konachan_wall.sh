#!/usr/bin/env bash
# Random SFW wallpaper from Konachan (hardened copy).
# Validates every step so a bad response never feeds a corrupt file to
# switchwall (which would crash the quickshell color pipeline).

set -u

get_pictures_dir() {
    if command -v xdg-user-dir &> /dev/null; then
        xdg-user-dir PICTURES
        return
    fi

    local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs"
    if [ -f "$config_file" ]; then
        local pictures_path
        pictures_path=$(source "$config_file" >/dev/null 2>&1; echo "$XDG_PICTURES_DIR")
        echo "${pictures_path/#\$HOME/$HOME}"
        return
    fi

    echo "$HOME/Pictures"
}

QUICKSHELL_CONFIG_NAME="ii"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
PICTURES_DIR=$(get_pictures_dir)
CONFIG_DIR="$XDG_CONFIG_HOME/quickshell/$QUICKSHELL_CONFIG_NAME"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$PICTURES_DIR/Wallpapers"

is_image() {
    local f="$1" head
    [ -s "$f" ] || return 1
    head=$(od -A n -t x1 -N 12 "$f" 2>/dev/null | tr -d ' \n')
    case "$head" in
        89504e47*)            return 0 ;; # PNG
        ffd8ff*)              return 0 ;; # JPEG
        47494638*)            return 0 ;; # GIF
        52494646*46574f54*)   return 0 ;; # WebP
        *66747970*)           return 0 ;; # AVIF/HEIF (ftyp brand)
        *)                    return 1 ;;
    esac
}

illogicalImpulseConfigPath="$HOME/.config/illogical-impulse/config.json"
userAgent=$(jq -r '.networking.userAgent // empty' "$illogicalImpulseConfigPath" 2>/dev/null)
[ -n "$userAgent" ] || userAgent="quickshell-ii/1.0"

page=$((1 + RANDOM % 1000))
response=$(curl --fail --silent --show-error --location --max-time 20 \
    -A "$userAgent" "https://konachan.net/post.json?tags=rating%3Asafe&limit=1&page=$page" 2>/dev/null) || {
    echo "Konachan is unreachable." >&2
    exit 0
}

link=$(echo "$response" | jq '.[0].file_url' -r 2>/dev/null)
if [ -z "$link" ] || [ "$link" = "null" ]; then
    echo "Konachan returned no usable post." >&2
    exit 0
fi

ext=$(echo "$link" | awk -F. '{print $NF}')
downloadPath="$PICTURES_DIR/Wallpapers/random_wallpaper.$ext"
currentWallpaperPath=$(jq -r '.background.wallpaperPath' "$illogicalImpulseConfigPath" 2>/dev/null)
if [ "$downloadPath" == "$currentWallpaperPath" ]; then
    downloadPath="$PICTURES_DIR/Wallpapers/random_wallpaper-1.$ext"
fi

curl --fail --silent --show-error --location --max-time 60 \
    -A "$userAgent" "$link" -o "$downloadPath" || {
    rm -f "$downloadPath"
    echo "Failed to download Konachan wallpaper." >&2
    exit 0
}

if ! is_image "$downloadPath"; then
    rm -f "$downloadPath"
    echo "Downloaded file is not a valid image." >&2
    exit 0
fi

"$SCRIPT_DIR/../switchwall.sh" --image "$downloadPath"
