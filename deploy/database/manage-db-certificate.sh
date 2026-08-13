#!/bin/sh
set -eu

repository=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
action=${1:-}
environment_file=${2:-"$repository/.env.production"}

case "$action" in issue|renew) ;; *)
    printf 'Usage: %s issue|renew [environment-file]\n' "$0" >&2
    exit 1
esac
test -f "$environment_file" || {
    printf 'ERROR: production environment file was not found.\n' >&2
    exit 1
}

docker compose --env-file "$environment_file" \
    -f "$repository/deploy/compose.production.yaml" \
    -f "$repository/deploy/compose.database-acme.yaml" \
    --profile database-acme run --rm database-certbot "$action"

if [ "$action" = renew ]; then
    "$repository/deploy/database/refresh-db-tls.sh" "$environment_file"
else
    printf 'Certificate issued. PostgreSQL remains unpublished.\n'
fi
