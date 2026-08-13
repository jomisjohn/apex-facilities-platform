#!/bin/sh
set -eu

source_certificate=/certificate-source/fullchain.pem
source_key=/certificate-source/privkey.pem
destination=/postgres-tls
minimum_validity=${APEX_DB_TLS_MIN_VALIDITY_SECONDS:-604800}

case "$minimum_validity" in
    *[!0-9]*|'')
        printf 'ERROR: APEX_DB_TLS_MIN_VALIDITY_SECONDS must be a positive integer.\n' >&2
        exit 1
        ;;
esac

if [ ! -s "$source_certificate" ] || [ ! -s "$source_key" ]; then
    printf 'ERROR: certificate source must contain non-empty fullchain.pem and privkey.pem.\n' >&2
    exit 1
fi

openssl x509 -in "$source_certificate" -noout -checkend "$minimum_validity" >/dev/null || {
    printf 'ERROR: database certificate is expired or expires inside the required safety window.\n' >&2
    exit 1
}

openssl x509 -in "$source_certificate" -noout -checkhost "$APEX_DB_DOMAIN" >/dev/null || {
    printf 'ERROR: database certificate does not match APEX_DB_DOMAIN.\n' >&2
    exit 1
}

certificate_key_hash=$(openssl x509 -in "$source_certificate" -pubkey -noout \
    | openssl pkey -pubin -outform DER 2>/dev/null \
    | sha256sum | awk '{print $1}')
private_key_hash=$(openssl pkey -in "$source_key" -pubout -outform DER 2>/dev/null \
    | sha256sum | awk '{print $1}')

if [ -z "$certificate_key_hash" ] || [ "$certificate_key_hash" != "$private_key_hash" ]; then
    printf 'ERROR: database certificate and private key do not match.\n' >&2
    exit 1
fi

postgres_uid=$(id -u postgres)
postgres_gid=$(id -g postgres)
temporary_certificate="$destination/.server.crt.$$"
temporary_key="$destination/.server.key.$$"
trap 'rm -f "$temporary_certificate" "$temporary_key"' EXIT HUP INT TERM

cp "$source_certificate" "$temporary_certificate"
cp "$source_key" "$temporary_key"
chown "$postgres_uid:$postgres_gid" "$temporary_certificate" "$temporary_key"
chmod 0644 "$temporary_certificate"
chmod 0600 "$temporary_key"
mv -f "$temporary_certificate" "$destination/server.crt"
mv -f "$temporary_key" "$destination/server.key"
trap - EXIT HUP INT TERM

printf 'Database TLS material is validated and ready.\n'
