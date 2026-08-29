{ config, lib, pkgs, ... }:

let
  cfg = config.services.pterodactyl;

  gameServers = {
    lobby = {
      uuid = "fd255e51-fba9-4a28-8b30-9b08f7959c6c";
      backupRepo = "/games/backups/backup-lobby/repo";
    };
    survival = {
      uuid = "88f35865-2993-4936-9bd3-fd3e345317c4";
      backupRepo = "/games/backups/backup-survival/repo";
    };
    creative = {
      uuid = "b4eaaa4d-2c34-46c5-ab25-6d974c108232";
      backupRepo = "/games/backups/backup-creative/repo";
    };
    velocity = {
      uuid = "a3f70d61-fc36-48e9-9013-10a2b48a726d";
      backupRepo = null;
    };
  };

  resticServers = lib.filterAttrs (_: s: s.backupRepo != null) gameServers;
  allServerNames = lib.attrNames gameServers;
  resticNames = lib.attrNames resticServers;

  apiKeyPath = config.sops.secrets."pterodactyl/bnuy-API_KEY".path;
  backupPasswordPath = config.sops.secrets."pterodactyl/backup_password".path;

  uuidCase = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: s:
    "    ${name}) echo \"${s.uuid}\" ;;"
  ) gameServers);

  repoCase = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: s:
    if s.backupRepo != null then "    ${name}) echo \"${s.backupRepo}\" ;;" else ""
  ) resticServers);

  bnuy = pkgs.writeShellScriptBin "bnuy" ''
    export PATH="${lib.makeBinPath [ pkgs.restic pkgs.jq pkgs.curl ]}:$PATH"

    # -- Colors (ANSI — works in kitty, tmux, everything) --------------------
    if [ -t 1 ]; then
      R=$'\033[0;31m'  G=$'\033[0;32m'  Y=$'\033[0;33m'
      M=$'\033[0;35m'  C=$'\033[0;36m'
      D=$'\033[0;90m'  BD=$'\033[1m'    RST=$'\033[0m'
    else
      R="" G="" Y="" M="" C="" D="" BD="" RST=""
    fi

    # -- Server map helpers --------------------------------------------------
    resolve-uuid() {
      case "$1" in
    ${uuidCase}
        *) echo "" ;;
      esac
    }

    resolve-repo() {
      case "$1" in
    ${repoCase}
        *) echo "" ;;
      esac
    }

    resolve-game-dir() {
      local uuid
      uuid=$(resolve-uuid "$1")
      [ -n "$uuid" ] && echo "${cfg.gamesDir}/''${uuid}"
    }

    # -- Panel API -----------------------------------------------------------
    ptero-post() {
      local uuid="$1" action="$2"
      curl -sk -X POST \
        -H "Authorization: Bearer $(cat ${apiKeyPath})" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        "https://127.0.0.1/api/client/servers/''${uuid}/power" \
        -d "{\"signal\":\"''${action}\"}"
    }

    # -- Pretty printers -----------------------------------------------------
    print_server_table() {
      printf "  ''${BD}%-14s %-38s %s''${RST}\n" "SERVER" "UUID" "BACKUP"
      printf "  %-14s %-38s %s\n" "------" "------------------------------------" "------"
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: s:
        ''printf "  ''${BD}%-14s''${RST} %-38s %s\n" "${name}" "${s.uuid}" "${if s.backupRepo != null then "yes" else "—"}"''
      ) gameServers)}
    }

    # -- Backup stats formatter ----------------------------------------------
    format_bytes() {
      local bytes=$1
      if   ((bytes >= 1073741824)); then echo "$((bytes / 1073741824)).$((bytes % 1073741824 / 107374182)) GiB"
      elif ((bytes >= 1048576));    then echo "$((bytes / 1048576)).$((bytes % 1048576 / 10485)) MiB"
      elif ((bytes >= 1024));       then echo "$((bytes / 1024)).$((bytes % 1024 / 102)) KiB"
      else echo "''${bytes} B"
      fi
    }

    # -- Help (same for -h and --help) ---------------------------------------
    show_help() {
      echo ""
      echo "  ''${BD}bnuy''${RST} — game server management"
      echo ""
      echo "  ''${BD}Usage:''${RST} bnuy <command> [args]"
      echo ""
      echo "  ''${BD}Commands:''${RST}"
      echo "    power      <server> <action>          power control via Panel API"
      echo "    rcon       <server> [command...]      RCON console (dump logs + live)"
      echo "    check      <action> [server]          inspect backup repos"
      echo "    rollback   <action> [server] [snap]   restore from backup"
      echo "    countdown  [seconds] [message]        broadcast + execute"
      echo ""
      echo "  ''${BD}Run 'bnuy <command> -h' for detailed help on each subcommand.''${RST}"
      echo ""
    }

    show_power_help() {
      echo ""
      echo "  ''${BD}bnuy power''${RST} — send power signal via Panel API"
      echo ""
      echo "  ''${BD}Usage:''${RST} bnuy power <server> <action>"
      echo ""
      echo "  ''${BD}Actions:''${RST}"
      echo "    start     Start the server"
      echo "    stop      Gracefully stop"
      echo "    restart   Restart the server"
      echo "    kill      Force-kill the server"
      echo ""
      echo "  ''${BD}Servers:''${RST}"
      print_server_table
      echo ""
    }

    show_rcon_help() {
      echo ""
      echo "  ''${BD}bnuy rcon''${RST} — RCON console"
      echo ""
      echo "  ''${BD}Usage:''${RST}"
      echo "    bnuy rcon <server>               dump logs + live RCON + log tail"
      echo "    bnuy rcon <server> <command>     run command and exit"
      echo ""
      echo "  ''${BD}Requires:''${RST} root"
      echo ""
      echo "  ''${BD}Servers:''${RST}"
      print_server_table
      echo ""
    }

    show_check_help() {
      echo ""
      echo "  ''${BD}bnuy check''${RST} — inspect restic backup repos"
      echo ""
      echo "  ''${BD}Usage:''${RST} bnuy check <action> [server]"
      echo ""
      echo "  ''${BD}Actions:''${RST}"
      echo "    stats       Show backup sizes + snapshot counts"
      echo "    snapshots   List snapshots (all or one server)"
      echo "    check       Run restic consistency check"
      echo "    unlock      Remove stale locks"
      echo ""
      echo "  ''${BD}Requires:''${RST} root for unlock"
      echo ""
      echo "  ''${BD}Servers:''${RST}"
      print_server_table
      echo ""
    }

    show_rollback_help() {
      echo ""
      echo "  ''${BD}bnuy rollback''${RST} — restore from backup"
      echo ""
      echo "  ''${BD}Usage:''${RST}"
      echo "    bnuy rollback list [server]"
      echo "    sudo bnuy rollback this <snapshot_id> <server>"
      echo "    sudo bnuy rollback undo <server>"
      echo ""
      echo "  ''${BD}Actions:''${RST}"
      echo "    list                       list snapshots"
      echo "    this   <id> <server>       restore to snapshot (saves current state)"
      echo "    undo   <server>            undo last restore (toggle: undo → redo → undo)"
      echo ""
      echo "  ''${BD}Safety:''${RST} Each restore creates a safety snapshot first."
      echo "  Undo is a toggle — run it again to redo."
      echo ""
      echo "  ''${BD}Servers:''${RST}"
      print_server_table
      echo ""
    }

    show_countdown_help() {
      echo ""
      echo "  ''${BD}bnuy countdown''${RST} — broadcast countdown + execute command"
      echo ""
      echo "  ''${BD}Usage:''${RST} sudo bnuy countdown [seconds] [message] [servers] [command]"
      echo ""
      echo "  ''${BD}Defaults:''${RST}"
      echo "    seconds  60"
      echo "    message  Scheduled Server restart is in"
      echo "    servers  all"
      echo ""
      echo "  ''${BD}Requires:''${RST} root"
      echo ""
      echo "  ''${BD}Examples:''${RST}"
      echo "    sudo bnuy countdown 120 'Restarting in' survival 'bnuy power survival restart'"
      echo "    sudo bnuy countdown 30"
      echo ""
    }

    # -- Subcommands ---------------------------------------------------------

    do_power() {
      if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then show_power_help; exit 0; fi
      local server="$1" action="$2"
      if [ -z "$server" ] || [ -z "$action" ]; then
        show_power_help; exit 1
      fi
      local uuid
      uuid=$(resolve-uuid "$server")
      if [ -z "$uuid" ]; then
        echo "''${R}[ERROR]''${RST} Unknown server: ''${BD}$server''${RST}"
        exit 1
      fi
      case "$action" in
        start|stop|restart|kill) ;;
        *)
          echo "''${R}[ERROR]''${RST} Invalid action: ''${BD}$action''${RST} (valid: start, stop, restart, kill)"
          exit 1
          ;;
      esac
      local resp
      resp=$(ptero-post "$uuid" "$action")
      if echo "$resp" | grep -q '"errors"'; then
        echo "''${R}[ERROR]''${RST} Panel API error:"
        echo "  $resp" | ${pkgs.jq}/bin/jq -r '.errors[].detail // empty' 2>/dev/null || echo "  $resp"
        exit 1
      fi
      echo "''${G}[OK]''${RST} ''${BD}$server''${RST}: $action"
    }

    do_rcon() {
      if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then show_rcon_help; exit 0; fi
      if [ "$EUID" -ne 0 ]; then
        echo "''${R}[ERROR]''${RST} RCON requires root. Try: ''${BD}sudo bnuy rcon''${RST}"
        exit 1
      fi
      local server="$1"; shift
      if [ -z "$server" ]; then
        echo "''${R}[ERROR]''${RST} No server specified."
        exit 1
      fi
      local uuid
      uuid=$(resolve-uuid "$server")
      if [ -z "$uuid" ]; then
        echo "''${R}[ERROR]''${RST} Unknown server: ''${BD}$server''${RST}"
        exit 1
      fi
      if [ $# -eq 0 ]; then
        echo "''${D}── last 40 lines ──''${RST}"
        docker logs --tail 40 "$uuid" 2>&1
        echo ""
        echo "''${D}── live logs + RCON (Ctrl+D to exit) ──''${RST}"
        echo ""
        docker logs --tail 0 -f "$uuid" 2>&1 &
        local logpid=$!
        docker exec -it "$uuid" rcon-cli
        kill "$logpid" 2>/dev/null; wait "$logpid" 2>/dev/null
        echo ""
        echo "''${D}── disconnected ──''${RST}"
      else
        local out rc=0
        out=$(docker exec "$uuid" rcon-cli "$@" 2>&1) || rc=$?
        if [ $rc -ne 0 ]; then
          echo "''${R}[ERROR]''${RST} rcon-cli failed (exit $rc):"
          [ -n "$out" ] && echo "  $out"
          exit "$rc"
        fi
        if echo "$out" | grep -qiE '(error|failed|timed.out|unknown command|invalid)'; then
          echo "''${R}[ERROR]''${RST} ''${BD}$server''${RST}: $out"
          exit 1
        fi
        [ -n "$out" ] && echo "$out"
        echo "''${G}[OK]''${RST} ''${BD}$server''${RST}: $*"
      fi
    }

    do_check() {
      if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then show_check_help; exit 0; fi
      if [ "$EUID" -ne 0 ]; then
        echo "''${R}[ERROR]''${RST} Requires root. Try: ''${BD}sudo bnuy check''${RST}"
        exit 1
      fi
      local action="$1" server="$2"
      if [ -z "$action" ]; then
        show_check_help; exit 1
      fi
      export RESTIC_PASSWORD_FILE="${backupPasswordPath}"
      case "$action" in
        stats)
          local total_snaps=0 total_raw=0 restore_bytes=0
          local oldest="" newest=""
          for srv in ${lib.concatStringsSep " " resticNames}; do
            if [ -n "$server" ] && [ "$srv" != "$server" ]; then continue; fi
            local repo
            repo=$(resolve-repo "$srv")
            [ -z "$repo" ] && continue

            local snap_json
            snap_json=$(restic -r "$repo" snapshots --json 2>/dev/null)
            local snaps
            snaps=$(echo "$snap_json" | ${pkgs.jq}/bin/jq 'length' 2>/dev/null || echo 0)
            local raw_json raw_bytes
            raw_json=$(restic -r "$repo" stats --mode raw-data --json 2>/dev/null)
            raw_bytes=$(echo "$raw_json" | ${pkgs.jq}/bin/jq -r '.total_size // 0' 2>/dev/null || echo 0)
            local rst_json rst_bytes
            rst_json=$(restic -r "$repo" stats --mode restore-size --json 2>/dev/null)
            rst_bytes=$(echo "$rst_json" | ${pkgs.jq}/bin/jq -r '.total_size // 0' 2>/dev/null || echo 0)

            total_snaps=$((total_snaps + snaps))
            total_raw=$((total_raw + raw_bytes))
            restore_bytes=$((restore_bytes + rst_bytes))

            local oldest_ts newest_ts
            oldest_ts=$(echo "$snap_json" | ${pkgs.jq}/bin/jq -r 'if length > 0 then .[-1].time else empty end' 2>/dev/null || echo "")
            newest_ts=$(echo "$snap_json" | ${pkgs.jq}/bin/jq -r 'if length > 0 then .[0].time else empty end' 2>/dev/null || echo "")
            if [ -n "$oldest_ts" ] && { [ -z "$oldest" ] || [[ "$oldest_ts" < "$oldest" ]]; }; then oldest="$oldest_ts"; fi
            if [ -n "$newest_ts" ] && { [ -z "$newest" ] || [[ "$newest_ts" > "$newest" ]]; }; then newest="$newest_ts"; fi
          done

          local oldest_fmt newest_fmt
          [ -n "$oldest" ] && oldest_fmt=$(date -d "$oldest" '+%Y-%m-%d' 2>/dev/null || echo "$oldest") || oldest_fmt="—"
          [ -n "$newest" ] && newest_fmt=$(date -d "$newest" '+%Y-%m-%d' 2>/dev/null || echo "$newest") || newest_fmt="—"

          local saved=$((restore_bytes - total_raw))
          local pct ratio
          pct=$(awk "BEGIN { if ($restore_bytes > 0) printf \"%.1f\", (($restore_bytes - $total_raw) / $restore_bytes) * 100; else print \"0.0\" }")
          ratio=$(awk "BEGIN { if ($total_raw > 0) printf \"%.2f\", $restore_bytes / $total_raw; else print \"0.00\" }")

          echo ""
          echo "  ''${BD}=========================================''${RST}"
          echo "  ''${BD}      BNUYHOLE NETWORK BACKUP STATS      ''${RST}"
          echo "  ''${BD}=========================================''${RST}"
          printf "  Total Snapshots    : ''${C}%s''${RST}\n" "$total_snaps"
          printf "  Range              : %s  ->  %s\n" "$oldest_fmt" "$newest_fmt"
          echo "  ''${D}-----------------------------------------''${RST}"
          for srv in ${lib.concatStringsSep " " resticNames}; do
            if [ -n "$server" ] && [ "$srv" != "$server" ]; then continue; fi
            local repo
            repo=$(resolve-repo "$srv")
            [ -z "$repo" ] && continue
            local sj sraw sb sc nt nf
            sj=$(restic -r "$repo" snapshots --json 2>/dev/null)
            sb=$(restic -r "$repo" stats --mode raw-data --json 2>/dev/null)
            sraw=$(echo "$sb" | ${pkgs.jq}/bin/jq -r '.total_size // 0' 2>/dev/null || echo 0)
            sc=$(echo "$sj" | ${pkgs.jq}/bin/jq 'length' 2>/dev/null || echo 0)
            nt=$(echo "$sj" | ${pkgs.jq}/bin/jq -r 'if length > 0 then .[0].time else empty end' 2>/dev/null || echo "")
            [ -n "$nt" ] && nf=$(date -d "$nt" '+%m-%d %H:%M' 2>/dev/null || echo "$nt") || nf="never"
            printf "  ''${BD}%-12s''${RST}  %-12s  (%s snaps, latest: ''${D}%s''${RST})\n" \
              "$srv" "$(format_bytes $sraw)" "$sc" "$nf"
          done
          echo "  ''${D}-----------------------------------------''${RST}"
          printf "  Uncompressed Size  : ''${BD}%s''${RST}\n" "$(format_bytes $restore_bytes)"
          printf "  Deduplicated Size  : ''${BD}%s''${RST}\n" "$(format_bytes $total_raw)"
          echo ""
          printf "  Dedup Saved        : ''${G}%s''${RST} !\n" "$(format_bytes $saved)"
          printf "  Dedup Ratio        : ''${G}%s:1''${RST}\n" "$ratio"
          printf "  Percentage smaller : ''${G}%s%%''${RST}\n" "$pct"
          echo "  ''${BD}=========================================''${RST}"
          echo ""
          ;;
        snapshots)
          for srv in ${lib.concatStringsSep " " resticNames}; do
            if [ -n "$server" ] && [ "$srv" != "$server" ]; then continue; fi
            echo "  ''${BD}$srv''${RST}"
            restic -r "$(resolve-repo "$srv")" snapshots 2>&1 | sed 's/^/    /' || echo "    ''${D}no snapshots''${RST}"
            echo ""
          done
          ;;
        check)
          for srv in ${lib.concatStringsSep " " resticNames}; do
            if [ -n "$server" ] && [ "$srv" != "$server" ]; then continue; fi
            echo "  ''${BD}$srv''${RST}: ''${D}running check...''${RST}"
            restic -r "$(resolve-repo "$srv")" check 2>&1 | sed 's/^/    /' || echo "    ''${Y}failed''${RST}"
          done
          ;;
        unlock)
          for srv in ${lib.concatStringsSep " " resticNames}; do
            echo "  ''${BD}$srv''${RST}"
            restic -r "$(resolve-repo "$srv")" unlock --remove-all 2>&1 | sed 's/^/    /' && \
              echo "    ''${G}[OK]''${RST} unlocked" || echo "    ''${D}nothing to unlock''${RST}"
          done
          ;;
        *)
          echo "''${R}[ERROR]''${RST} Unknown action: ''${BD}$action''${RST}"
          show_check_help; exit 1
          ;;
      esac
    }

    do_rollback() {
      if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then show_rollback_help; exit 0; fi
      if [ "$EUID" -ne 0 ]; then
        echo "''${R}[ERROR]''${RST} Rollback requires root. Try: ''${BD}sudo bnuy rollback''${RST}"
        exit 1
      fi

      export RESTIC_PASSWORD_FILE="${backupPasswordPath}"

      # Find mc-backup sidecar container for a server
      find-backup-ctr() {
        local srv="$1"
        for c in $(docker ps -aq); do
          local img
          img=$(docker inspect -f '{{.Config.Image}}' "$c" 2>/dev/null)
          if echo "$img" | grep -q "mc-backup"; then
            local hname
            hname=$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$c" 2>/dev/null | grep "^RESTIC_HOSTNAME=" | cut -d= -f2)
            if [ "$hname" = "backup-$srv" ]; then
              echo "$c"
              return 0
            fi
          fi
        done
        return 1
      }

      # Create safety snapshot: RCON flush + restic backup from host
      # Outputs new snapshot ID to stdout
      backup-now() {
        local srv="$1"
        local uuid repo dataDir
        uuid=$(resolve-uuid "$srv")
        repo=$(resolve-repo "$srv")
        [ -z "$uuid" ] && { echo "  ''${R}[ERROR]''${RST} Unknown server: $srv" >&2; return 1; }
        [ -z "$repo" ] && { echo "  ''${R}[ERROR]''${RST} No backup repo for $srv" >&2; return 1; }
        dataDir=$(resolve-game-dir "$srv")

        echo "  ''${M}[ACTION]''${RST} Flushing world..." >&2
        docker exec "$uuid" rcon-cli save-off >/dev/null 2>&1 || true
        docker exec "$uuid" rcon-cli save-all flush >/dev/null 2>&1 || true
        sleep 2

        echo "  ''${M}[ACTION]''${RST} Creating safety snapshot..." >&2
        rm -rf "/games-src/''${uuid}"
        mkdir -p "/games-src/''${uuid}"
        mount --bind "$dataDir" "/games-src/''${uuid}"
        local out
        out=$(restic -r "$repo" backup "/games-src/''${uuid}" \
          --tag "safety" --host "backup-$srv" \
          --no-cache 2>&1) || {
          umount "/games-src/''${uuid}" 2>/dev/null
          echo "$out" | sed 's/^/    /' >&2
          echo "  ''${R}[ERROR]''${RST} Restic backup failed" >&2
          docker exec "$uuid" rcon-cli save-on >/dev/null 2>&1 || true
          return 1
        }
        echo "$out" | sed 's/^/    /' >&2
        umount "/games-src/''${uuid}"
        docker exec "$uuid" rcon-cli save-on >/dev/null 2>&1 || true

        echo "$out" | grep -oP '^snapshot \K[a-f0-9]+'
      }

      get-container-user() {
        local uuid="$1"
        local user
        user=$(docker inspect -f '{{.Config.User}}' "$uuid" 2>/dev/null || echo "")
        if [ -n "$user" ] && [[ "$user" =~ ^[0-9]+(:[0-9]+)?$ ]]; then
          echo "$user"
        else
          echo "1000:1000"
        fi
      }

      # Pure restore primitive: stop → restore → chown → start
      do-restore() {
        local snap_id="$1" srv="$2"
        local uuid repo dataDir
        uuid=$(resolve-uuid "$srv")
        repo=$(resolve-repo "$srv")
        [ -z "$uuid" ] && { echo "''${R}[ERROR]''${RST} Unknown server: $srv"; exit 1; }
        [ -z "$repo" ] && { echo "''${R}[ERROR]''${RST} No backup repo for $srv"; exit 1; }
        dataDir=$(resolve-game-dir "$srv")

        echo "''${M}[ACTION]''${RST} Stopping ''${BD}$srv''${RST}..."
        docker stop --time 30 "$uuid" >/dev/null 2>&1 || true
        local waited=0
        while docker inspect -f '{{.State.Running}}' "$uuid" 2>/dev/null | grep -q true; do
          sleep 2; waited=$((waited + 2))
          if [ "$waited" -ge 60 ]; then
            echo "  ''${Y}[WARN]''${RST} Force-killing..."
            docker kill "$uuid" >/dev/null 2>&1 || true
            break
          fi
        done
        echo "''${G}[OK]''${RST} ''${BD}$srv''${RST} stopped"

        echo "''${M}[ACTION]''${RST} Restoring from snapshot ''${BD}$snap_id''${RST}..."
        local tmpdir="/tmp/mc-restore-$$"
        mkdir -p "$tmpdir"
        trap 'rm -rf "$tmpdir"' EXIT

        local restore_rc=0
        restic -r "$repo" restore "$snap_id" --target "$tmpdir" --no-cache --no-lock 2>&1 | sed 's/^/    /' || restore_rc=$?
        if [ "$restore_rc" -ne 0 ]; then
          rm -rf "$tmpdir"; trap - EXIT
          echo "''${R}[ERROR]''${RST} Restic restore failed (exit $restore_rc)"
          exit 1
        fi

        if [ ! -d "$tmpdir/games-src/''${uuid}" ]; then
          rm -rf "$tmpdir"; trap - EXIT
          echo "''${R}[ERROR]''${RST} Restore verification failed: expected path not found"
          exit 1
        fi

        echo "  ''${D}Swapping files...''${RST}"
        rm -rf "$dataDir"
        mv "$tmpdir/games-src/''${uuid}" "$dataDir"
        rm -rf "$tmpdir"; trap - EXIT
        echo "''${G}[OK]''${RST} Restore complete"

        local container_user
        container_user=$(get-container-user "$uuid")
        echo "''${M}[ACTION]''${RST} Fixing permissions (''${BD}$container_user''${RST})..."
        chown -R "$container_user" "$dataDir"
        sync
        echo "''${G}[OK]''${RST} Permissions fixed"

        echo "''${M}[ACTION]''${RST} Starting ''${BD}$srv''${RST}..."
        ptero-post "$uuid" start
        local waited=0
        while [ "$waited" -lt 360 ]; do
          sleep 30; waited=$((waited + 30))
          docker exec "$uuid" rcon-cli list >/dev/null 2>&1 && {
            echo "''${G}[OK]''${RST} ''${BD}$srv''${RST} started"
            return 0
          }
        done
        echo "''${Y}[WARN]''${RST} Timed out waiting for ''${BD}$srv''${RST} to respond to RCON"
      }

      local action="$1"; shift
      case "$action" in
        list)
          local server="$1"
          for srv in ${lib.concatStringsSep " " resticNames}; do
            if [ -n "$server" ] && [ "$srv" != "$server" ]; then continue; fi
            echo "  ''${BD}$srv''${RST}"
            restic -r "$(resolve-repo "$srv")" snapshots 2>&1 | sed 's/^/    /' || echo "    ''${D}no snapshots''${RST}"
            echo ""
          done
          ;;
        this)
          local snap_id="$1" srv="$2"
          if [ -z "$snap_id" ] || [ -z "$srv" ]; then
            echo "''${R}[ERROR]''${RST} Usage: ''${BD}sudo bnuy rollback this <snapshot_id> <server>''${RST}"
            exit 1
          fi
          local repo
          repo=$(resolve-repo "$srv")
          [ -z "$repo" ] && { echo "''${R}[ERROR]''${RST} No backup repo for $srv"; exit 1; }

          echo "''${M}[ACTION]''${RST} Verifying snapshot ''${BD}$snap_id''${RST}..."
          if ! restic -r "$repo" cat snapshot "$snap_id" >/dev/null 2>&1; then
            echo "''${R}[ERROR]''${RST} Snapshot not found: ''${BD}$snap_id''${RST}"
            echo "  Run ''${BD}bnuy rollback list $srv''${RST} to see available snapshots"
            exit 1
          fi
          echo "''${G}[OK]''${RST} Snapshot verified"

          local stateDir="/var/lib/mc-admin/.rollback/''${srv}"
          mkdir -p "$stateDir"

          local safety_id rc=0
          safety_id=$(backup-now "$srv") || rc=$?
          [ $rc -ne 0 ] && exit 1
          [ -z "$safety_id" ] && { echo "''${R}[ERROR]''${RST} No snapshot created"; exit 1; }
          echo "$safety_id" > "$stateDir/last-safety-id"
          echo "''${G}[OK]''${RST} Safety snapshot: ''${BD}$safety_id''${RST}"

          do-restore "$snap_id" "$srv"
          restic -r "$repo" forget \
            --keep-last 3 --keep-hourly 24 --keep-weekly 7 \
            --keep-monthly 4 --keep-yearly 2 \
            --prune 2>&1 | sed 's/^/    /' || true
          ;;
        undo)
          local srv="$1"
          if [ -z "$srv" ]; then
            echo "''${R}[ERROR]''${RST} Usage: ''${BD}sudo bnuy rollback undo <server>''${RST}"
            exit 1
          fi
          local stateDir="/var/lib/mc-admin/.rollback/''${srv}"
          [ ! -f "$stateDir/last-safety-id" ] && {
            echo "''${R}[ERROR]''${RST} No undo history for $srv"
            exit 1
          }
          local restore_id
          restore_id=$(cat "$stateDir/last-safety-id")
          local repo
          repo=$(resolve-repo "$srv")

          echo "''${M}[ACTION]''${RST} Verifying undo snapshot ''${BD}$restore_id''${RST}..."
          if ! restic -r "$repo" cat snapshot "$restore_id" >/dev/null 2>&1; then
            echo "''${R}[ERROR]''${RST} Undo snapshot not found: ''${BD}$restore_id''${RST}"
            echo "  Run ''${BD}bnuy rollback list $srv''${RST} to see available snapshots"
            exit 1
          fi
          echo "''${G}[OK]''${RST} Snapshot verified"

          echo "''${M}[ACTION]''${RST} Restoring to ''${BD}$restore_id''${RST}..."
          do-restore "$restore_id" "$srv"
          restic -r "$repo" forget \
            --keep-last 3 --keep-hourly 24 --keep-weekly 7 \
            --keep-monthly 4 --keep-yearly 2 \
            --prune 2>&1 | sed 's/^/    /' || true
          ;;
        *)
          echo "''${R}[ERROR]''${RST} Unknown action: ''${BD}$action''${RST}"
          show_rollback_help; exit 1
          ;;
      esac
    }

    do_countdown() {
      if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then show_countdown_help; exit 0; fi
      if [ "$EUID" -ne 0 ]; then
        echo "''${R}[ERROR]''${RST} Requires root. Try: ''${BD}sudo bnuy countdown''${RST}"
        exit 1
      fi

      local total="''${1:-60}"
      local msg_prefix="''${2:-Scheduled Server restart is in}"
      local target_servers="''${3:-all}"
      local command="''${4:-}"

      if ! [[ "$total" =~ ^[0-9]+$ ]]; then
        echo "''${R}[ERROR]''${RST} Invalid duration: ''${BD}$total''${RST} (must be a number)"
        echo "  Usage: ''${BD}sudo bnuy countdown [seconds] [message] [servers] [command]''${RST}"
        exit 1
      fi

      broadcast() {
        local bmsg="$1"
        local targets=()
        if [ "$target_servers" = "all" ]; then
          targets=(${lib.concatStringsSep " " allServerNames})
        else
          targets=("$target_servers")
        fi
        for target in "''${targets[@]}"; do
          local buuid
          buuid=$(resolve-uuid "$target")
          [ -n "$buuid" ] && docker exec "$buuid" rcon-cli say "$bmsg" >/dev/null 2>&1 || true
        done
      }

      echo "''${M}[COUNTDOWN]''${RST} ''${BD}$total''${RST} seconds..."
      for ((t = total; t > 0; t--)); do
        if   ((t % 3600 == 0 && t != 0)); then msg="$msg_prefix $((t / 3600)) Hour(s)";   broadcast "$msg"; echo "  ''${Y}$msg''${RST}"
        elif ((t % 300 == 0 && t != 0));  then msg="$msg_prefix $((t / 60)) Minute(s)";    broadcast "$msg"; echo "  ''${Y}$msg''${RST}"
        elif ((t == 60 || t == 30 || t == 15)); then msg="$msg_prefix $t SECONDS";         broadcast "$msg"; echo "  ''${Y}$msg''${RST}"
        elif ((t <= 10));                  then msg="$msg_prefix $t";                       broadcast "$msg"; echo "  ''${R}$msg''${RST}"
        fi
        sleep 1
      done
      if [ -n "$command" ]; then
        echo "''${M}[ACTION]''${RST} Executing: ''${BD}$command''${RST}"
        eval "$command"
      else
        echo "''${G}[OK]''${RST} Countdown complete"
      fi
    }

    # -- Main dispatch -------------------------------------------------------
    case "''${1:-}" in
      power)     shift; do_power "$@" ;;
      rcon)      shift; do_rcon "$@" ;;
      check)     shift; do_check "$@" ;;
      rollback)  shift; do_rollback "$@" ;;
      countdown) shift; do_countdown "$@" ;;
      -h|--help) show_help ;;
      "")
        echo "No command specified, for a list of commands, try \"bnuy -h\""
        exit 1
        ;;
      *)
        echo "Unknown command: ''${BD}$1''${RST}. Try \"bnuy -h\" for a list."
        exit 1
        ;;
    esac
  '';
in
{
  options.services.pterodactyl.mcAdmin = lib.mkEnableOption "bnuy game server management command";

  config = lib.mkIf (cfg.enable && cfg.mcAdmin) {
    sops.secrets."pterodactyl/bnuy-API_KEY" = {
      sopsFile = ./secrets.yaml;
      owner = "root";
      mode = "0400";
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/mc-admin/.rollback 0700 root root -"
    ] ++ lib.mapAttrsToList (name: s:
      "d /var/lib/mc-admin/.rollback/${name} 0700 root root -"
    ) resticServers;

    environment.systemPackages = [ bnuy ];
  };
}
