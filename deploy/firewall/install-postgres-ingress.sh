#!/bin/sh
set -eu

repository=/opt/apex-facilities-platform
unit_source="$repository/deploy/systemd/apex-postgres-ingress.service"
unit_target=/etc/systemd/system/apex-postgres-ingress.service
guard="$repository/deploy/firewall/apply-postgres-ingress.sh"

test "$(id -u)" -eq 0 || {
    printf 'ERROR: install the PostgreSQL ingress guard as root.\n' >&2
    exit 1
}
test -x "$guard" || {
    printf 'ERROR: the executable PostgreSQL ingress guard is missing.\n' >&2
    exit 1
}
test -f "$unit_source" || {
    printf 'ERROR: the PostgreSQL ingress systemd unit is missing.\n' >&2
    exit 1
}
command -v iptables >/dev/null 2>&1 || {
    printf 'ERROR: iptables is required.\n' >&2
    exit 1
}
systemctl is-active --quiet docker.service || {
    printf 'ERROR: Docker must be active before installing the ingress guard.\n' >&2
    exit 1
}
iptables --wait --list DOCKER-USER >/dev/null 2>&1 || {
    printf 'ERROR: Docker DOCKER-USER chain is unavailable.\n' >&2
    exit 1
}

install -o root -g root -m 0644 "$unit_source" "$unit_target"
systemctl daemon-reload
systemctl enable apex-postgres-ingress.service
systemctl restart apex-postgres-ingress.service
systemctl is-active --quiet apex-postgres-ingress.service

# Fail installation unless the active kernel rules contain the managed jump
# and excess-new-connection drop. The database bind remains unchanged.
iptables --wait --check DOCKER-USER --protocol tcp \
    --destination-port 5432 --jump APEX-POSTGRES-INGRESS
iptables --wait --check APEX-POSTGRES-INGRESS --match conntrack \
    --ctstate NEW --jump DROP

printf 'Apex PostgreSQL ingress guard is installed and active.\n'
