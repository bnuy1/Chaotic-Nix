#!/bin/bash
# Updates FancyHolograms time_leaderboard + auto-ranks players to 'green' after 10 minutes
# Runs via mc-leaderboard.service/timer (see pterodactyl.nix). __MC_DB_PASS_FILE__
# is substituted with the sops secret path at eval time.

DB_PASS=$(cat __MC_DB_PASS_FILE__)

# Query top 3 players by total playtime
TOP3=$(docker exec -i minecraft-db mariadb -uroot -p"$DB_PASS" --batch --skip-column-names loritime -e "
SELECT 
  p.name,
  COALESCE(SUM(
    CASE 
      WHEN t.leave_time IS NOT NULL THEN TIMESTAMPDIFF(SECOND, t.join_time, t.leave_time)
      ELSE TIMESTAMPDIFF(SECOND, t.join_time, NOW())
    END
  ), 0) as total_seconds
FROM loritime_player p
LEFT JOIN loritime_time t ON t.player_id = p.id
GROUP BY p.id, p.name
ORDER BY total_seconds DESC
LIMIT 3;
" 2>/dev/null)

format_time() {
    local secs=$1
    if [ "$secs" -ge 86400 ]; then
        local days=$((secs / 86400))
        local hours=$(( (secs % 86400) / 3600 ))
        echo "${days}d ${hours}h"
    elif [ "$secs" -ge 3600 ]; then
        local hours=$((secs / 3600))
        local mins=$(( (secs % 3600) / 60 ))
        echo "${hours}h ${mins}m"
    elif [ "$secs" -ge 60 ]; then
        local mins=$((secs / 60))
        echo "${mins}m"
    else
        echo "${secs}s"
    fi
}

LINE=1
E1="&e1st &7- &bNo data"
E2="&e2nd &7- &bNo data"
E3="&e3rd &7- &bNo data"
while IFS=$'\t' read -r name seconds; do
    [ -z "$name" ] && continue
    formatted=$(format_time "$seconds")
    case $LINE in
        1) E1="&e1st &f${name} &7- &b${formatted}" ;;
        2) E2="&e2nd &f${name} &7- &b${formatted}" ;;
        3) E3="&e3rd &f${name} &7- &b${formatted}" ;;
    esac
    LINE=$((LINE + 1))
done <<< "$TOP3"

# Write hologram file
HOLOGRAM="/games/pterodactyl/fd255e51-fba9-4a28-8b30-9b08f7959c6c/plugins/FancyHolograms/holograms.yml"

cat > "$HOLOGRAM" << HOEOF
version: 2
holograms:
  time_leaderboard:
    type: TEXT
    location:
      world: world
      x: -3.5661427881036305
      y: 1.0
      z: 14.530752513674988
      yaw: -90.0
      pitch: 36.749996
    visibility_distance: -1
    visibility: ALL
    persistent: true
    scale_x: 1.0
    scale_y: 1.0
    scale_z: 1.0
    translation_x: 0.0
    translation_y: 0.0
    translation_z: 0.0
    shadow_radius: 0.0
    shadow_strength: 1.0
    text:
    - '&6&lTime Leaderboard'
    - '${E1}'
    - '${E2}'
    - '${E3}'
    text_shadow: false
    see_through: false
    text_alignment: center
    update_text_interval: -1
    billboard: horizontal
    background: '#c855ffff'
HOEOF

# Reload FancyHolograms via rcon
docker exec fd255e51-fba9-4a28-8b30-9b08f7959c6c rcon-cli "fancyholograms reload" 2>/dev/null

# === AUTO-RANK: Promote to 'green' after 10 minutes (600s) ===
# loritime_player.uuid is BINARY(16); luckperms_players.uuid is a dashed varchar.
docker exec -i minecraft-db mariadb -uroot -p"$DB_PASS" --batch --skip-column-names loritime -e "
SELECT
  lp.name,
  CONCAT(
    LOWER(SUBSTR(HEX(lp.uuid), 1, 8)), '-',
    LOWER(SUBSTR(HEX(lp.uuid), 9, 4)), '-',
    LOWER(SUBSTR(HEX(lp.uuid), 13, 4)), '-',
    LOWER(SUBSTR(HEX(lp.uuid), 17, 4)), '-',
    LOWER(SUBSTR(HEX(lp.uuid), 21, 12))
  ) as lp_uuid
FROM loritime_player lp
JOIN luckperms.luckperms_players u ON u.uuid = CONCAT(
    LOWER(SUBSTR(HEX(lp.uuid), 1, 8)), '-',
    LOWER(SUBSTR(HEX(lp.uuid), 9, 4)), '-',
    LOWER(SUBSTR(HEX(lp.uuid), 13, 4)), '-',
    LOWER(SUBSTR(HEX(lp.uuid), 17, 4)), '-',
    LOWER(SUBSTR(HEX(lp.uuid), 21, 12))
)
WHERE u.primary_group = 'default'
AND lp.id IN (
    SELECT t.player_id
    FROM loritime_time t
    GROUP BY t.player_id
    HAVING COALESCE(SUM(
        CASE
            WHEN t.leave_time IS NOT NULL THEN TIMESTAMPDIFF(SECOND, t.join_time, t.leave_time)
            ELSE TIMESTAMPDIFF(SECOND, t.join_time, NOW())
        END
    ), 0) >= 600
);
" 2>/dev/null | while IFS=$'\t' read -r name uuid; do
    [ -z "$name" ] && continue
    # Rank via the LuckPerms command, NOT raw SQL: applies to online players
    # immediately and syncs across the network. Raw DB edits are invisible to
    # LuckPerms' in-memory cache and can be overwritten by its own saves.
    # </dev/null: keep rcon from eating the loop's stdin.
    if OUT=$(docker exec fd255e51-fba9-4a28-8b30-9b08f7959c6c rcon-cli \
        "lp user $uuid parent set green" 2>&1 < /dev/null); then
        echo "$(date): Auto-ranked: $name -> green"
    else
        echo "$(date): WARN: could not rank $name (lobby down?): $OUT" >&2
    fi
done
