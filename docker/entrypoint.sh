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

# 暫存目錄由 server 自己建（<系統暫存目錄>/cage-<uid>，只有它的帳號能用），這裡不再預先建 /tmp/cage。
mkdir -p "${CFG_DIR}" /opt/cage/data

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
        "${template}" > "${target}"
    chmod 600 "${target}"
}
if [[ ! -f "${CONFIG_FILE}" ]]; then
    seed "${TEMPLATES}/config.xml.template" "${CONFIG_FILE}"
    # No MYSQL_PASSWORD = no database on purpose: leave <mysql> out. With the block in
    # place the server waits for that database before serving anything — it never
    # takes "the database is not up yet" for "there are no accounts" and starts open.
    if [[ -z "${MYSQL_PASSWORD:-}" ]]; then
        # Anchored to the element lines: a comment that mentions <mysql> stays intact.
        sed -i '/^[[:space:]]*<mysql>/,/^[[:space:]]*<\/mysql>/d' "${CONFIG_FILE}"
    fi
fi
seed "${TEMPLATES}/control.xml.template" "${CONTROL_CONFIG}"

# ── The example passwords from the docs ─────────────────────────────────────
# The old .env.example shipped ADMIN_PASSWORD=change-me-admin. Copied and started
# as is, the admin password is a value printed in public docs, and the AI API
# port (where admins sign in too) is published on every interface.
is_placeholder() { [[ "${1,,}" == change-me* || "${1,,}" == change_me* ]]; }
if is_placeholder "${ADMIN_PASSWORD:-}"; then
    log "ADMIN_PASSWORD is still the example value from the docs - refusing to start."
    log "Set your own in .env, then: docker compose up -d"
    exit 1
fi
# Deployed from the old docs: control.xml was generated on the first start with the
# example password, and seed() never rewrites it, so a new ADMIN_PASSWORD in .env
# would not reach it. Put the new one in; the control plane then replaces the
# admin's example password in the database too (ControlService::init).
admin_pw_in_file=$(sed -n '/<admin>/,/<\/admin>/ s|.*<password>\(.*\)</password>.*|\1|p' \
                       "${CONTROL_CONFIG}" | head -n 1)
if is_placeholder "${admin_pw_in_file}" && [[ -n "${ADMIN_PASSWORD:-}" ]]; then
    # XML first (& < >), then what sed's replacement treats specially (& | \).
    esc=$(printf '%s' "${ADMIN_PASSWORD}" \
          | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/[|\\&]/\\&/g')
    sed -i "/<admin>/,/<\/admin>/ s|<password>[^<]*</password>|<password>${esc}</password>|" \
        "${CONTROL_CONFIG}"
    log "control.xml had the example admin password - replaced it with ADMIN_PASSWORD from .env"
fi

# ── Ownership of the bind-mounted folders ───────────────────────────────────
# The container runs as root, so everything it creates on a bind mount is
# root-owned and mode 600 — which leaves you unable to edit config.xml from the
# host without sudo, even though the docs tell you to. Set PUID/PGID to your own
# ids (id -u / id -g) and the folders become yours.
if [[ -n "${PUID:-}" && -n "${PGID:-}" ]]; then
    log "chown ${PUID}:${PGID} on /config, /opt/cage/data"
    chown -R "${PUID}:${PGID}" "${CFG_DIR}" /opt/cage/data 2>/dev/null || \
        log "chown failed (continuing)"
fi

# ── Warnings that are cheap here and confusing later ────────────────────────
if [[ -z "${MYSQL_PASSWORD:-}" ]]; then
    if grep -q '<mysql>' "${CONFIG_FILE}" 2>/dev/null; then
        # An existing config is never rewritten here: a forgotten MYSQL_PASSWORD must
        # not quietly turn into an open server.
        log "WARNING: no MYSQL_PASSWORD, but ${CONFIG_FILE} has a <mysql> block - the server"
        log "         will wait for that database before serving anything. To run without a"
        log "         database, remove the <mysql> block from it."
    else
        log "WARNING: no database - the server runs open (dev-open): every request on the API"
        log "         port is served as admin, with no sign-in. Anyone who can reach that port can"
        log "         read every session and change graphs. Single-user trial only; set <api_key>"
        log "         in ${CONFIG_FILE} to require a token."
    fi
fi
if [[ -z "${ADMIN_PASSWORD:-}" ]]; then
    log "WARNING: no ADMIN_PASSWORD — the control plane web UI is unauthenticated"
fi
if [[ ! -d /models ]] || [[ -z "$(ls -A /models 2>/dev/null)" ]]; then
    log "NOTE: /models is empty — mount your model directories there"
fi

# ── Wait for the database, if one is configured ─────────────────────────────
# Without this the server starts first, fails to connect, and silently runs in
# open mode — which looks like a permissions bug rather than a race.
#
# There is no "give up and start anyway": a server that starts without its
# database has no accounts, so every request on the published API port is let in
# as an admin. Waiting is the safe side; the log says what it is waiting for.
if [[ -n "${MYSQL_PASSWORD:-}" ]]; then
    host="${MYSQL_HOST:-mysql}"; port="${MYSQL_PORT:-3306}"
    log "waiting for ${host}:${port}"
    waited=0
    until mysqladmin ping -h "${host}" -P "${port}" \
            -u"${MYSQL_USER:-cage}" -p"${MYSQL_PASSWORD}" --silent 2>/dev/null; do
        waited=$((waited + 1))
        (( waited % 30 == 0 )) && log "still waiting for the database at ${host}:${port} (${waited}s)"
        sleep 1
    done
    log "database is up"
    # Idempotent: the schema uses CREATE TABLE IF NOT EXISTS.
    if [[ -f /opt/cage/sql/schema.sql ]]; then
        mysql -h "${host}" -P "${port}" -u"${MYSQL_USER:-cage}" \
              -p"${MYSQL_PASSWORD}" "${MYSQL_DATABASE:-cage}" \
              < /opt/cage/sql/schema.sql 2>/dev/null \
            && log "schema applied" || log "could not apply the schema (continuing)"
    fi
fi

log "starting cage-launcher $*"
cd /opt/cage
exec ./bin/cage-launcher "$@" \
    --config "${CONFIG_FILE}" \
    --control-config "${CONTROL_CONFIG}"
