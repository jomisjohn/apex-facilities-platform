#!/bin/sh
set -eu

migration_directory=/migrations

psql --set=ON_ERROR_STOP=1 --quiet <<'SQL'
CREATE TABLE IF NOT EXISTS public.apex_schema_migrations (
    migration_name text PRIMARY KEY,
    sha256 text NOT NULL,
    applied_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON public.apex_schema_migrations FROM PUBLIC;
SQL

find "$migration_directory" -maxdepth 1 -type f -name '*.sql' -print | sort | while IFS= read -r migration_path; do
    migration_name=$(basename "$migration_path")
    checksum=$(sha256sum "$migration_path" | awk '{print $1}')
    escaped_name=$(printf '%s' "$migration_name" | sed "s/'/''/g")
    existing=$(psql --tuples-only --no-align --set=ON_ERROR_STOP=1 \
        --command="SELECT sha256 FROM public.apex_schema_migrations WHERE migration_name = '$escaped_name';")

    if [ -n "$existing" ]; then
        if [ "$existing" != "$checksum" ]; then
            printf 'ERROR: applied migration %s has changed; add a new migration instead.\n' "$migration_name" >&2
            exit 1
        fi
        printf 'SKIP: %s already applied.\n' "$migration_name"
        continue
    fi

    psql --set=ON_ERROR_STOP=1 --quiet --file="$migration_path"
    psql --set=ON_ERROR_STOP=1 --quiet \
        --command="INSERT INTO public.apex_schema_migrations (migration_name, sha256) VALUES ('$escaped_name', '$checksum');"
    printf 'APPLIED: %s\n' "$migration_name"
done
