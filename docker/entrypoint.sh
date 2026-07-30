#!/usr/bin/env bash
#
# Container entrypoint: seed the configs on first run, optionally wait for the
# database, then hand over to aiw-launcher as PID 1's child.
set -euo pipefail

CFG_DIR="${CFG_DIR:-/config}"
CONFIG_FILE="${CONFIG_FILE:-${CFG_DIR}/config.xml}"
CONTROL_CONFIG="${AIW_CONTROL_CONFIG:-${CFG_DIR}/control.xml}"
TEMPLATES=/opt/aiwrapper/templates

log() { printf '[entrypoint] %s\n' "$*"; }

mkdir -p "${CFG_DIR}" /data /venvs /tmp/aiwrapper/modality

# ── First run: seed configs ─────────────────────────────────────────────────
# Substituted from the environment so a compose file can set the database
# password and the admin password without editing XML by hand.
seed() {
    local template="$1" target="$2"
    [[ -f "${target}" ]] && return 0
    log "creating ${target} from the template"
    sed -e "s|@MYSQL_HOST@|${MYSQL_HOST:-mysql}|g" \
        -e "s|@MYSQL_PORT@|${MYSQL_PORT:-3306}|g" \
        -e "s|@MYSQL_USER@|${MYSQL_USER:-aiwrapper}|g" \
        -e "s|@MYSQL_PASSWORD@|${MYSQL_PASSWORD:-}|g" \
        -e "s|@MYSQL_DATABASE@|${MYSQL_DATABASE:-aiwrapper}|g" \
        -e "s|@ADMIN_USER@|${ADMIN_USER:-admin}|g" \
        -e "s|@ADMIN_PASSWORD@|${ADMIN_PASSWORD:-}|g" \
        -e "s|@NODE_TOKEN@|${NODE_TOKEN:-}|g" \
        -e "s|@UNSLOTH_PYTHON@|${UNSLOTH_PYTHON:-/venvs/llm/bin/python}|g" \
        "${template}" > "${target}"
    chmod 600 "${target}"
}
seed "${TEMPLATES}/config.xml.template"  "${CONFIG_FILE}"
seed "${TEMPLATES}/control.xml.template" "${CONTROL_CONFIG}"

# ── Warnings that are cheap here and confusing later ────────────────────────
if [[ -z "${MYSQL_PASSWORD:-}" ]]; then
    log "WARNING: no MYSQL_PASSWORD — the server will run without a database"
    log "         (no accounts, no per-user sessions; fine for a local trial)"
fi
if [[ -z "${ADMIN_PASSWORD:-}" ]]; then
    log "WARNING: no ADMIN_PASSWORD — the control plane web UI is unauthenticated"
fi
if [[ ! -x "${UNSLOTH_PYTHON:-/venvs/llm/bin/python}" ]]; then
    log "NOTE: no worker environment at ${UNSLOTH_PYTHON:-/venvs/llm/bin/python}"
    log "      models using the unsloth backend cannot load until you build one:"
    log "        docker compose exec aiwrapper ./setup-workers.sh --prefix /venvs"
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
             -u"${MYSQL_USER:-aiwrapper}" -p"${MYSQL_PASSWORD}" --silent 2>/dev/null; then
            log "database is up"
            # Idempotent: the schema uses CREATE TABLE IF NOT EXISTS.
            if [[ -f /opt/aiwrapper/sql/schema.sql ]]; then
                mysql -h "${host}" -P "${port}" -u"${MYSQL_USER:-aiwrapper}" \
                      -p"${MYSQL_PASSWORD}" "${MYSQL_DATABASE:-aiwrapper}" \
                      < /opt/aiwrapper/sql/schema.sql 2>/dev/null \
                    && log "schema applied" || log "could not apply the schema (continuing)"
            fi
            break
        fi
        [[ $i -eq 60 ]] && log "database did not come up in 60s — starting anyway"
        sleep 1
    done
fi

log "starting aiw-launcher $*"
cd /opt/aiwrapper
exec ./bin/aiw-launcher "$@" \
    --config "${CONFIG_FILE}" \
    --control-config "${CONTROL_CONFIG}"
