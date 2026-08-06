#!/usr/bin/env bash
set -euo pipefail

# Pterodactyl Panel setup script for NixOS.
# Run AFTER nixos-rebuild switch with services.pterodactyl.enable = true.
#
# Functionality merged from the old desktop.sh (banner, colors, logging,
# argument parsing) and setup-pterodactyl.sh (panel deployment).

DATA_DIR="/srv/pterodactyl"
PANEL_VERSION="v1.15.0"
REPO="https://github.com/pterodactyl/panel"
DB_NAME="pterodactyl"
DB_USER="pterodactyl"

creator_art=(
  "    ▄▄▄                    "
  "   ██▀▀█▄                  "
  "   ██ ▄█▀ ▄                "
  "   ██▀▀█▄ ████▄ ██ ██ ██ ██"
  " ▄ ██  ▄█ ██ ██ ██ ██ ██▄██"
  " ▀██████▀▄██ ▀█▄▀██▀█▄▄▀██▀"
  "                        ██ "
  "           :3         ▀▀▀ "
)

goodbye_message="Thank you for using my program, goodbye, and have a great day!"

# defaults
noconfirm=false
nochecks=false
nocolor=false
quiet=false
verbose=false
TARBALL=""
admin_args=()

# prettier colors (auto-disabled if piped)
if [ -t 1 ]; then
  OK="$(tput setaf 2)[OK]$(tput sgr0)"
  ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
  NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
  INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
  WARN="$(tput setaf 3)[WARN]$(tput sgr0)"
  ACTION="$(tput setaf 6)[ACTION]$(tput sgr0)"

  RED="$(tput setaf 1)"
  GREEN="$(tput setaf 2)"
  YELLOW="$(tput setaf 3)"
  BLUE="$(tput setaf 4)"
  MAGENTA="$(tput setaf 5)"
  CYAN="$(tput setaf 6)"
  WHITE="$(tput setaf 7)"
  C_RESET="$(tput sgr0)"
else
  OK="[OK]"
  ERROR="[ERROR]"
  NOTE="[NOTE]"
  INFO="[INFO]"
  WARN="[WARN]"
  ACTION="[ACTION]"

  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  MAGENTA=""
  CYAN=""
  WHITE=""
  C_RESET=""
fi
palette=("$BLUE" "$MAGENTA" "$WHITE" "$MAGENTA")

log() {
  local msg="$1"
  local force="${2:-}"

  if [[ "$quiet" == true && "$force" != "force" ]]; then
    return 0
  fi

  if [[ "$nocolor" == true ]]; then
    msg=$(printf '%s' "$msg" |
      sed -r 's/\x1B\[[0-9;]*[mK]//g')
  fi

  if [[ "$verbose" == true ]]; then
    local timestamp="[$(date +"%Y-%m-%d %H:%M:%S")] "
  else
    local timestamp=""
  fi

  echo "${timestamp}${msg}${C_RESET}"
}

error() {
  log "${RED}[ERROR] ${C_RESET}$*" force
}

parse_arguments() {
  while test $# -gt 0; do
    case "$1" in
    -h | --help | help)
      echo -e "This script sets up the Pterodactyl panel on NixOS. :3

usage: $0 {Flags..} [action]

Actions:
  install (default)  Download the panel, install Composer dependencies, then
                     re-run the declarative .env / DB-password / migration /
                     queue services managed by the NixOS module.
  uninstall          Stop the pterodactyl services and remove the panel data.
                     Optionally drops the '${DB_NAME}' database too.
  admin              Create an administrator account (artisan p:user:make).
                     Extra arguments after 'admin' are forwarded to artisan,
                     e.g. 'admin --no-password' or 'admin --email=... --username=...'.
  status             Show the state of the pterodactyl systemd services.

Valid Flags:
-h,  --help,    shows this menu and exits
--noconfirm,    Never prompts the user and assumes defaults
--nochecks,     Does not perform system safety checks and runs blindly
-nc, --nocolor, Does not show colored output :(
-q, --quiet,    Silences non required information
-v, --verbose,  Output includes timestamps"
      exit 0
      ;;
    --noconfirm)
      noconfirm=true
      shift
      ;;
    --nochecks)
      nochecks=true
      shift
      ;;
    -nc | --nocolor | --nocolors)
      nocolor=true
      shift
      ;;
    -q | --quiet)
      quiet=true
      shift
      ;;
    -v | --verbose)
      verbose=true
      shift
      ;;
    install | setup)
      action="install"
      shift
      ;;
    uninstall)
      action="uninstall"
      shift
      ;;
    admin)
      action="admin"
      shift
      # Forward any remaining arguments to artisan p:user:make,
      # e.g. --no-password, --username=..., --email=...
      while test $# -gt 0; do
        admin_args+=("$1")
        shift
      done
      ;;
    status)
      action="status"
      shift
      ;;
    *)
      error "unexpected argument : '${*}' found
usage $0 {Flags..} [action]
for more information, try '--help'"
      exit 1
      ;;
    esac
  done
  action="${action:-install}"
}

check_root() {
  if [[ "$nochecks" == false ]]; then
    if [[ "$(id -u)" -ne 0 ]]; then
      error "This script must be run as root. try: sudo $0"
      exit 1
    fi
  fi
}

prompt_user() {
  local prompt="$1"
  local default="${2:-y}"
  local answer
  while true; do
    read -r -p "$prompt (${default^^}/$(if [[ "$default" == "y" ]]; then echo "N"; else echo "Y"; fi)) " answer
    answer="${answer:-$default}"
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      return 0
    elif [[ "$answer" =~ ^[Nn]$ ]]; then
      return 1
    else
      error "Invalid input, please type Y or N."
    fi
  done
}

print_art() {
  local -n art=$1
  local terminal_width pad max_width padded
  local -a raw
  terminal_width=$(tput cols 2>/dev/null || echo 80)
  raw=()

  max_width=0
  for line in "${art[@]}"; do
    ((${#line} > max_width)) && max_width=${#line}
  done

  for line in "${art[@]}"; do
    padded=$(printf "%-*s" "$max_width" "$line")
    ((max_width >= terminal_width)) && pad=0 || pad=$(((terminal_width - max_width) / 2))
    raw+=("$(printf "%*s%s" "$pad" "" "$padded")")
  done

  for i in "${!raw[@]}"; do
    color="${palette[i % ${#palette[@]}]}"
    log "${color}${raw[i]}"
  done
}

check_endpoint() {
  local url="$1" code
  code="$(curl -ks --max-time 5 -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || true)"
  [[ "$code" =~ ^[0-9]{3}$ ]]
}

panel_endpoint() {
  # Prefer https; fall back to http only if the TLS endpoint doesn't respond.
  local app_url https_url http_url
  app_url="$(grep -m1 '^APP_URL=' "${DATA_DIR}/.env" 2>/dev/null | cut -d= -f2-)"
  if [[ -z "$app_url" ]]; then
    log "${WARN} No APP_URL in ${DATA_DIR}/.env yet; panel endpoint unknown."
    return 1
  fi
  if check_endpoint "$app_url"; then
    log "${OK} Panel is live at: ${app_url}"
  else
    https_url="$app_url"
    http_url="http://${https_url#https://}"
    if check_endpoint "$http_url"; then
      log "${OK} Panel is live at: ${http_url} (https endpoint not responding)"
    else
      log "${WARN} Panel not responding yet — check 'systemctl status nginx phpfpm-pterodactyl'"
      return 1
    fi
  fi
}

restart_services() {
  # .env, DB password and migrations are managed declaratively by the module's
  # systemd services; re-run them now that the panel files are in place.
  log "${INFO} Re-running declarative services (.env, DB password, migrations, queue)..."
  if ! systemctl restart pterodactyl-set-db-password.service \
    pterodactyl-env.service pterodactyl-migrate.service pteroq.service; then
    log "${WARN} one or more services failed; check 'systemctl status pterodactyl-*'"
  fi
}

install_panel() {
  TARBALL="$(mktemp)"
  trap 'rm -f "${TARBALL:-}"' EXIT

  log "${INFO} Downloading panel release ${PANEL_VERSION}..."
  curl -fsSL -o "${TARBALL}" \
    "${REPO}/releases/download/${PANEL_VERSION}/panel.tar.gz"

  log "${INFO} Extracting to ${DATA_DIR}..."
  rm -rf "${DATA_DIR:?}"/*
  tar -xzf "${TARBALL}" -C "${DATA_DIR}"

  log "${INFO} Setting ownership so composer/artisan run as pterodactyl..."
  chown -R pterodactyl:pterodactyl "${DATA_DIR}"
  chmod 750 "${DATA_DIR}"
  chmod 755 "${DATA_DIR}/public"

  # nix-shell must run as root (nix daemon only serves @wheel); composer/artisan
  # are then dropped to pterodactyl so created files keep the right owner.
  log "${INFO} Installing Composer dependencies..."
  local composer_flags=(--no-dev --optimize-autoloader --no-interaction)
  [[ "$quiet" == true ]] && composer_flags+=(--quiet)
  nix-shell -p php83 php83Packages.composer --run \
    "cd ${DATA_DIR} && sudo -u pterodactyl composer install ${composer_flags[*]}"

  log "${INFO} Fixing permissions..."
  chmod -R 755 "${DATA_DIR}/storage" "${DATA_DIR}/bootstrap/cache"

  restart_services
}

uninstall_panel() {
  log "${WARN} Stopping pterodactyl services..."
  systemctl stop wings.service pteroq.service pterodactyl-migrate.service \
    pterodactyl-env.service pterodactyl-set-db-password.service 2>/dev/null || true

  log "${WARN} Removing ${DATA_DIR} and /etc/pterodactyl..."
  rm -rf "${DATA_DIR}" /etc/pterodactyl

  if prompt_user "Drop the '${DB_NAME}' database and '${DB_USER}' user?" n; then
    log "${WARN} Dropping database '${DB_NAME}' and user '${DB_USER}'..."
    nix-shell -p mariadb --run \
      "mariadb -e \"DROP DATABASE IF EXISTS ${DB_NAME}; DROP USER IF EXISTS '${DB_USER}'@'localhost'; FLUSH PRIVILEGES;\"" ||
      log "${ERROR} failed to drop database (is the pterodactyl MySQL instance running?)"
  fi

  echo ""
  log "${NOTE} Remember to disable 'services.pterodactyl.enable' in the NixOS"
  log "${NOTE} config and run 'nixos-rebuild switch' to remove the module."
}

create_admin() {
  log "${INFO} Creating administrator account..."
  nix-shell -p php83 --run \
    "sudo -u pterodactyl php ${DATA_DIR}/artisan p:user:make ${admin_args[*]}"
}

show_status() {
  local units=(wings pteroq phpfpm-pterodactyl pterodactyl-migrate pterodactyl-env nginx)
  log "${INFO} Pterodactyl service status:"
  for u in "${units[@]}"; do
    local state
    state="$(systemctl is-active "$u" 2>/dev/null || true)"
    [[ -n "$state" ]] || state="inactive"
    printf "  %-28s %s\n" "$u" "$state"
  done
  if [[ -f "${DATA_DIR}/.env" ]]; then
    log "${OK} Panel .env present at ${DATA_DIR}/.env"
  else
    log "${WARN} Panel .env missing (pterodactyl-env.service has not succeeded)"
  fi
}

main() {
  parse_arguments "$@"
  case "$action" in
  install)
    check_root
    palette=("$BLUE" "$BLUE" "$MAGENTA" "$WHITE" "$MAGENTA")
    print_art creator_art
    if [[ "$noconfirm" == false ]]; then
      if ! prompt_user "This script will download and deploy the Pterodactyl panel. Continue?"; then
        error "User denied action. Script exited."
        exit 1
      fi
    fi
    install_panel
    panel_endpoint || true
    if [[ "$noconfirm" == true ]]; then
      log "${NOTE} Create an admin account later with: sudo $0 admin"
    else
      if prompt_user "Create an administrator account now?"; then
        create_admin
      fi
    fi
    palette=("$MAGENTA")
    print_art goodbye_message
    ;;
  uninstall)
    check_root
    palette=("$BLUE" "$BLUE" "$MAGENTA" "$WHITE" "$MAGENTA")
    print_art creator_art
    if [[ "$noconfirm" == false ]]; then
      if ! prompt_user "This will remove the Pterodactyl panel from this system. Continue?"; then
        error "User denied action. Script exited."
        exit 1
      fi
    fi
    uninstall_panel
    ;;
  admin)
    check_root
    create_admin
    ;;
  status)
    show_status
    ;;
  esac
}

main "$@"
