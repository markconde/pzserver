#!/usr/bin/env bash

set -Eeuo pipefail
[[ "${DEBUG:-false}" == "true" ]] && set -x

EDIT_CONFIG_SCRIPT="/home/steam/edit_server_config.py"

shutdown() {
    printf "\n### Shutdown requested...\n"

    # Prefer graceful shutdown via RCON if enabled and available
    if [[ "${RCON_ENABLED}" == "true" ]] && command -v rcon >/dev/null 2>&1; then
        printf "### Using RCON quit on %s:%s\n" "${BIND_IP}" "${RCON_PORT}"

        if ! rcon --address "${BIND_IP}:${RCON_PORT}" --password "${RCON_PASSWORD}" quit; then
            printf "### RCON quit command failed, falling back to SIGTERM.\n"
            [[ -n "${server_pid:-}" ]] && kill "${server_pid}" 2>/dev/null || pkill -P $$ || true
            return
        fi

        # Give it a moment to shut down
        sleep 5

        if [[ -n "${server_pid:-}" ]] && ps -p "${server_pid}" >/dev/null 2>&1; then
            printf "### Server still running after RCON quit, sending SIGTERM...\n"
            kill "${server_pid}" 2>/dev/null || pkill -P $$ || true
        else
            printf "### Server process appears to have exited after RCON quit.\n"
        fi
    else
        printf "### RCON not enabled or rcon binary not found; using SIGTERM.\n"
        [[ -n "${server_pid:-}" ]] && kill "${server_pid}" 2>/dev/null || pkill -P $$ || true
    fi
}

start_server() {
    printf "\n### Starting Project Zomboid Server...\n"

    local cmd=(
        "${BASE_GAME_DIR}/start-server.sh"
        -cachedir="${CONFIG_DIR}"
        -adminusername "${ADMIN_USERNAME}"
        -adminpassword "${ADMIN_PASSWORD}"
        -ip "${BIND_IP}"
        -port "${DEFAULT_PORT}"
        -servername "${SERVER_NAME}"
        -steamvac "${STEAM_VAC}"
        "${USE_STEAM}"
    )

    if [[ "${TIMEOUT}" -gt 0 ]]; then
        timeout "${TIMEOUT}" "${cmd[@]}" &
    else
        "${cmd[@]}" &
    fi

    server_pid=$!
    wait "${server_pid}" || true
    wait "${server_pid}" || true

    printf "\n### Project Zomboid Server stopped.\n"
}

apply_config_from_env() {
    printf "\n### Applying server configuration from environment (PZ_* variables)...\n"

    # Provide sane defaults for key settings, but let explicit PZ_* override
    : "${PZ_SaveWorldEveryMinutes:=${AUTOSAVE_INTERVAL}}"
    : "${PZ_DefaultPort:=${DEFAULT_PORT}}"
    : "${PZ_UDPPort:=${UDP_PORT}}"
    : "${PZ_MaxPlayers:=${MAX_PLAYERS}}"
    : "${PZ_Map:=${MAP_NAMES}}"
    : "${PZ_WorkshopItems:=${MOD_WORKSHOP_IDS}}"
    : "${PZ_Mods:=${MOD_NAMES}}"
    : "${PZ_PauseEmpty:=${PAUSE_ON_EMPTY}}"
    : "${PZ_Open:=${PUBLIC_SERVER}}"
    : "${PZ_PublicName:=${SERVER_NAME}}"
    : "${PZ_Password:=${SERVER_PASSWORD}}"
    : "${PZ_RCONPort:=${RCON_PORT}}"
    : "${PZ_RCONPassword:=${RCON_PASSWORD}}"

    export PZ_SaveWorldEveryMinutes PZ_DefaultPort PZ_UDPPort PZ_MaxPlayers
    export PZ_Map PZ_WorkshopItems PZ_Mods PZ_PauseEmpty PZ_Open
    export PZ_PublicName PZ_Password PZ_RCONPort PZ_RCONPassword

    python3 "${EDIT_CONFIG_SCRIPT}" --bulk-from-env "${SERVER_CONFIG}"

    printf "\n### Applying JVM configuration (MAX_RAM, GC_CONFIG)...\n"
    sed -i "s/-Xmx.*/-Xmx${MAX_RAM}\",/g" "${SERVER_VM_CONFIG}"
    sed -i "s/-XX:+Use.*/-XX:+Use${GC_CONFIG}\",/g" "${SERVER_VM_CONFIG}"

    printf "\n### Configuration from environment applied.\n"
}

test_first_run() {
    printf "\n### Checking if this is the first run...\n"

    if [[ ! -f "${SERVER_CONFIG}" ]] || [[ ! -f "${SERVER_RULES_CONFIG}" ]]; then
        printf "\n### This is the first run.\nStarting server for %s seconds to generate configs\n" "${TIMEOUT}"
        start_server
        TIMEOUT=0
    else
        printf "\n### This is not the first run.\n"
        TIMEOUT=0
    fi

    printf "\n### First run check complete.\n"
}

update_server() {
    printf "\n### Updating Project Zomboid Server via SteamCMD...\n"

    local game_version="${GAME_VERSION:-public}"

    steamcmd.sh \
      +@ShutdownOnFailedCommand 0 \
      +@NoPromptForPassword 1 \
      +force_install_dir "${BASE_GAME_DIR}" \
      +login anonymous \
      +app_update 380870 -beta "${game_version}" validate \
      +quit

    printf "\n### Project Zomboid Server updated.\n"
}

set_variables() {
    printf "\n### Setting variables...\n"

    TIMEOUT="${TIMEOUT:-60}"  # time for initial config generation
    AUTO_UPDATE="${AUTO_UPDATE:-true}"

    BASE_GAME_DIR="/home/steam/ZomboidDedicatedServer"
    CONFIG_DIR="/home/steam/Zomboid"

    ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
    ADMIN_PASSWORD="${ADMIN_PASSWORD:-changeme}"
    AUTOSAVE_INTERVAL="${AUTOSAVE_INTERVAL:-15}"

    BIND_IP="${BIND_IP:-0.0.0.0}"
    mkdir -p "${CONFIG_DIR}"
    
    DEFAULT_PORT="${DEFAULT_PORT:-16261}"
    UDP_PORT="${UDP_PORT:-16262}"

    GAME_VERSION="${GAME_VERSION:-public}"
    MAX_PLAYERS="${MAX_PLAYERS:-16}"
    MAX_RAM="${MAX_RAM:-4096m}"
    GC_CONFIG="${GC_CONFIG:-ZGC}"

    MOD_NAMES="${MOD_NAMES:-}"
    MOD_WORKSHOP_IDS="${MOD_WORKSHOP_IDS:-}"
    MAP_NAMES="${MAP_NAMES:-Muldraugh, KY}"

    PAUSE_ON_EMPTY="${PAUSE_ON_EMPTY:-true}"
    PUBLIC_SERVER="${PUBLIC_SERVER:-true}"

    SERVER_NAME="${SERVER_NAME:-ZomboidServer}"
    SERVER_PASSWORD="${SERVER_PASSWORD:-}"

    STEAM_VAC="${STEAM_VAC:-true}"

    if [[ -z "${USE_STEAM:-}" ]] || [[ "${USE_STEAM}" == "true" ]]; then
        USE_STEAM=""
    else
        USE_STEAM="-nosteam"
    fi

    RCON_PORT="${RCON_PORT:-27015}"
    RCON_PASSWORD="${RCON_PASSWORD:-changeme_rcon}"
    if [[ "${RCON_PORT}" == "0" ]]; then
        RCON_ENABLED="false"
    else
        RCON_ENABLED="true"
    fi

    SERVER_CONFIG="${CONFIG_DIR}/Server/${SERVER_NAME}.ini"
    SERVER_VM_CONFIG="${BASE_GAME_DIR}/ProjectZomboid64.json"
    SERVER_RULES_CONFIG="${CONFIG_DIR}/Server/${SERVER_NAME}_SandboxVars.lua"

    printf "\n### Variables set.\n"
}

set_variables

if [[ "${AUTO_UPDATE}" == "true" ]]; then
    update_server
else
    printf "\n### AUTO_UPDATE is disabled; skipping SteamCMD update.\n"
fi

test_first_run
apply_config_from_env

trap shutdown SIGTERM SIGINT

start_server