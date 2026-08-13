#!/bin/sh
set -eu

repository=/opt/apex-facilities-platform
unit_source="$repository/deploy/systemd"
unit_target=/etc/systemd/system

test "$(id -u)" -eq 0 || {
    printf 'ERROR: install the renewal timer as root.\n' >&2
    exit 1
}
test -x "$repository/deploy/database/manage-db-certificate.sh" || {
    printf 'ERROR: the Apex deployment repository is missing or incomplete.\n' >&2
    exit 1
}
test -f "$repository/.env.production" || {
    printf 'ERROR: the private production environment file is missing.\n' >&2
    exit 1
}

install -o root -g root -m 0644 \
    "$unit_source/apex-db-certificate-renew.service" \
    "$unit_target/apex-db-certificate-renew.service"
install -o root -g root -m 0644 \
    "$unit_source/apex-db-certificate-renew.timer" \
    "$unit_target/apex-db-certificate-renew.timer"

systemctl daemon-reload
systemctl enable --now apex-db-certificate-renew.timer
systemctl start apex-db-certificate-renew.service
systemctl is-active --quiet apex-db-certificate-renew.timer
systemctl is-failed --quiet apex-db-certificate-renew.service && {
    systemctl status --no-pager apex-db-certificate-renew.service >&2
    exit 1
}

printf 'Apex database certificate renewal timer is installed and active.\n'
