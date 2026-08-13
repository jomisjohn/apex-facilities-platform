#!/bin/sh
set -eu

case "${APEX_PREVIEW_ALIAS:-}" in
    *[!a-z0-9]*|'')
        printf 'ERROR: APEX_PREVIEW_ALIAS must contain 8-24 lowercase letters or numbers.\n' >&2
        exit 1
        ;;
esac

alias_length=${#APEX_PREVIEW_ALIAS}
if [ "$alias_length" -lt 8 ] || [ "$alias_length" -gt 24 ]; then
    printf 'ERROR: APEX_PREVIEW_ALIAS must contain 8-24 lowercase letters or numbers.\n' >&2
    exit 1
fi

if [ "${#APEX_PREVIEW_PASSWORD}" -lt 16 ]; then
    printf 'ERROR: APEX_PREVIEW_PASSWORD must contain at least 16 characters.\n' >&2
    exit 1
fi

# psql variables and format() keep the password out of SQL text and logs.
workspace_schema=$(psql --tuples-only --no-align --set=ON_ERROR_STOP=1 \
    --set=preview_alias="$APEX_PREVIEW_ALIAS" \
    --set=preview_password="$APEX_PREVIEW_PASSWORD" <<'SQL'
SELECT public.apex_provision_workspace(
    'AIDA 1145',
    :'preview_alias',
    :'preview_password'
);
SQL
)

expected_workspace="ws_aida1145_${APEX_PREVIEW_ALIAS}"
if [ "$workspace_schema" != "$expected_workspace" ]; then
    printf 'ERROR: preview workspace provisioning returned an unexpected identifier.\n' >&2
    exit 1
fi

# Keep a redeployed preview login synchronized with the current secret. The
# identifier and value are quoted by PostgreSQL format(), not shell-concatenated.
psql --quiet --set=ON_ERROR_STOP=1 \
    --set=preview_role="apex_u_${APEX_PREVIEW_ALIAS}" \
    --set=preview_password="$APEX_PREVIEW_PASSWORD" <<'SQL'
SELECT format('ALTER ROLE %I PASSWORD %L', :'preview_role', :'preview_password') \gexec
SQL

printf 'Preview workspace is ready.\n'
