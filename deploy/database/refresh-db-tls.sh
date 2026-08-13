#!/bin/sh
set -eu

repository=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
environment_file=${1:-"$repository/.env.production"}

if [ ! -f "$environment_file" ]; then
    printf 'ERROR: production environment file was not found.\n' >&2
    exit 1
fi

compose() {
    docker compose \
        --env-file "$environment_file" \
        -f "$repository/deploy/compose.production.yaml" \
        -f "$repository/deploy/compose.database-tls.yaml" \
        "$@"
}

compose run --rm tls-prepare
compose kill --signal HUP database

for attempt in 1 2 3 4 5 6; do
    if compose exec -T database sh -c \
        'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"' >/dev/null 2>&1; then
        printf 'Database TLS certificate reload completed.\n'
        exit 0
    fi
    sleep 2
done

printf 'ERROR: PostgreSQL did not report ready after the TLS reload.\n' >&2
exit 1
