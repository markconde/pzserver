#!/usr/bin/env bash
set -Eeuo pipefail

# If RCON_PORT is 0, treat as "healthcheck disabled"
RCON_PORT="${RCON_PORT:-27015}"
RCON_PASSWORD="${RCON_PASSWORD:-changeme_rcon}"
BIND_IP="${BIND_IP:-127.0.0.1}"

if [[ "${RCON_PORT}" == "0" ]]; then
  # RCON disabled; don't fail healthcheck
  exit 0
fi

if ! command -v rcon >/dev/null 2>&1; then
  exit 1
fi

ADDR="${BIND_IP}:${RCON_PORT}"

# Try a harmless command; only care about success/failure
if rcon --address "${ADDR}" --password "${RCON_PASSWORD}" "players" >/dev/null 2>&1; then
  exit 0
else
  exit 1
fi