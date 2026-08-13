#!/usr/bin/env bash
#
# Container entrypoint: seed the configs on first run, optionally wait for the
# database, then hand over to cage-launcher as PID 1's child.
set -euo pipefail

CFG_DIR="${CFG_DIR:-/config}"
CONFIG_FILE="${CONFIG_FILE:-${CFG_DIR}/config.xml}"
CONTROL_CONFIG="${CAGE_CONTROL_CONFIG:-${CFG_DIR}/control.xml}"
TEMPLATES=/opt/cage/templates

log() { printf '[entrypoint] %s\n' "$*"; }

mkdir -p "${CFG_DIR}" /opt/cage/data /venvs /tmp/cage/modality

# ── First run: seed configs ─────────────────────────────────────────────────
# Substituted from the environment so a compose file can set the database
# password and the admin password without editing XML by hand.
seed() {
    local template="$1" target="$2"
    [[ -f "${target}" ]] && return 0
    log "creating ${target} from the template"
    sed -e "s|@MYSQL_HOST@|${MYSQL_HOST:-mysql}|g" \
        -e "s|@MYSQL_PORT@|${MYSQL_PORT:-3306}|g" \
        -e "s|@MYSQL_USER@|${MYSQL_USER:-cage}|g" \
        -e "s|@MYSQL_PASSWORD@|${MYSQL_PASSWORD:-}|g" \
        -e "s|@MYSQL_DATABASE@|${MYSQL_DATABASE:-cage}|g" \
        -e "s|@ADMIN_USER@|${ADMIN_USER:-admin}|g" \
        -e "s|@ADMIN_PASSWORD@|${ADMIN_PASSWORD:-}|g" \
        -e "s|@NODE_TOKEN@|${NODE_TOKEN:-}|g" \
        -e "s|@VLLM_PYTHON@|${VLLM_PYTHON:-}|g" \
        "${template}" > "${target}"
    chmod 600 "${target}"
}
seed "${TEMPLATES}/config.xml.template"  "${CONFIG_FILE}"
seed "${TEMPLATES}/control.xml.template" "${CONTROL_CONFIG}"

# ── Ownership of the bind-mounted folders ───────────────────────────────────
# The container runs as root, so everything it creates on a bind mount is
# root-owned and mode 600 — which leaves you unable to edit config.xml from the
# host without sudo, even though the docs tell you to. Set PUID/PGID to your own
# ids (id -u / id -g) and the folders become yours.
if [[ -n "${PUID:-}" && -n "${PGID:-}" ]]; then
    log "chown ${PUID}:${PGID} on /config, /opt/cage/data, /venvs, /tmp/cage"
    chown -R "${PUID}:${PGID}" "${CFG_DIR}" /opt/cage/data /venvs /tmp/cage 2>/dev/null || \
        log "chown failed (continuing)"
fi

# ── Warnings that are cheap here and confusing later ────────────────────────
if [[ -z "${MYSQL_PASSWORD:-}" ]]; then
    log "WARNING: no MYSQL_PASSWORD — the server will run without a database"
    log "         (no accounts, no per-user sessions; fine for a local trial)"
fi
if [[ -z "${ADMIN_PASSWORD:-}" ]]; then
    log "WARNING: no ADMIN_PASSWORD — the control plane web UI is unauthenticated"
fi
# vLLM is only needed for safetensors models; a GGUF-only deployment runs the
# in-process llama backend and needs nothing installed. Only warn if the
# variable is set but wrong — an empty one is a deliberate "not using it".
if [[ -n "${VLLM_PYTHON:-}" ]] && [[ ! -x "${VLLM_PYTHON}" ]]; then
    log "WARNING: VLLM_PYTHON=${VLLM_PYTHON} is not executable"
    log "         safetensors (backend=\"vllm\") models will not load. Build it with:"
    log "           docker compose exec cage python3 -m venv /venvs/vllm"
    log "           docker compose exec cage /venvs/vllm/bin/pip install vllm"
fi
if [[ ! -d /models ]] || [[ -z "$(ls -A /models 2>/dev/null)" ]]; then
    log "NOTE: /models is empty — mount your model directories there"
fi

# ── Wait for the database, if one is configured ─────────────────────────────
# Without this the server starts first, fails to connect, and silently runs in
# open mode — which looks like a permissions bug rather than a race.
if [[ -n "${MYSQL_PASSWORD:-}" ]]; then
    host="${MYSQL_HOST:-mysql}"; port="${MYSQL_PORT:-3306}"
    log "waiting for ${host}:${port}"
    for i in $(seq 1 60); do
        if mysqladmin ping -h "${host}" -P "${port}" \
             -u"${MYSQL_USER:-cage}" -p"${MYSQL_PASSWORD}" --silent 2>/dev/null; then
            log "database is up"
            # Idempotent: the schema uses CREATE TABLE IF NOT EXISTS.
            if [[ -f /opt/cage/sql/schema.sql ]]; then
                mysql -h "${host}" -P "${port}" -u"${MYSQL_USER:-cage}" \
                      -p"${MYSQL_PASSWORD}" "${MYSQL_DATABASE:-cage}" \
                      < /opt/cage/sql/schema.sql 2>/dev/null \
                    && log "schema applied" || log "could not apply the schema (continuing)"
            fi
            break
        fi
        [[ $i -eq 60 ]] && log "database did not come up in 60s — starting anyway"
        sleep 1
    done
fi

log "starting cage-launcher $*"
cd /opt/cage
exec ./bin/cage-launcher "$@" \
    --config "${CONFIG_FILE}" \
    --control-config "${CONTROL_CONFIG}"
