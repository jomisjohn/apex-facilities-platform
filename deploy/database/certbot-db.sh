#!/bin/sh
set -eu

action=${1:-}
webroot=/var/www/acme
certificate_export=/certificate-export
lineage="/etc/letsencrypt/live/${APEX_DB_DOMAIN}"

case "${APEX_DB_DOMAIN:-}" in
    *[!A-Za-z0-9.-]*|'')
        printf 'ERROR: APEX_DB_DOMAIN is not a valid DNS hostname.\n' >&2
        exit 1
        ;;
esac
case "${APEX_ACME_EMAIL:-}" in
    *@*.*) ;;
    *)
        printf 'ERROR: APEX_ACME_EMAIL must be a valid private certificate contact.\n' >&2
        exit 1
        ;;
esac

export_certificate() {
    test -s "$lineage/fullchain.pem" && test -s "$lineage/privkey.pem" || {
        printf 'ERROR: Certbot did not produce the expected certificate lineage.\n' >&2
        exit 1
    }
    temporary_certificate="$certificate_export/.fullchain.pem.$$"
    temporary_key="$certificate_export/.privkey.pem.$$"
    trap 'rm -f "$temporary_certificate" "$temporary_key"' EXIT HUP INT TERM
    cp -L "$lineage/fullchain.pem" "$temporary_certificate"
    cp -L "$lineage/privkey.pem" "$temporary_key"
    chmod 0644 "$temporary_certificate"
    chmod 0600 "$temporary_key"
    mv -f "$temporary_certificate" "$certificate_export/fullchain.pem"
    mv -f "$temporary_key" "$certificate_export/privkey.pem"
    trap - EXIT HUP INT TERM
}

case "$action" in
    issue)
        certbot certonly --non-interactive --agree-tos --no-eff-email \
            --email "$APEX_ACME_EMAIL" --cert-name "$APEX_DB_DOMAIN" \
            --domains "$APEX_DB_DOMAIN" --authenticator webroot \
            --webroot-path "$webroot" --preferred-challenges http \
            --keep-until-expiring
        export_certificate
        ;;
    renew)
        certbot renew --non-interactive --cert-name "$APEX_DB_DOMAIN" --deploy-hook /usr/local/bin/certbot-export-db
        ;;
    export)
        export_certificate
        ;;
    *)
        printf 'ERROR: use certbot-db issue, renew, or export.\n' >&2
        exit 1
        ;;
esac

printf 'Database certificate action completed successfully.\n'
