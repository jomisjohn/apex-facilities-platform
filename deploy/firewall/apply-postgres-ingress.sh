#!/bin/sh
set -eu

chain=APEX-POSTGRES-INGRESS
docker_chain=DOCKER-USER
postgres_port=5432
rate=150/second
burst=180

test "$(id -u)" -eq 0 || {
    printf 'ERROR: PostgreSQL ingress rules require root.\n' >&2
    exit 1
}
command -v iptables >/dev/null 2>&1 || {
    printf 'ERROR: iptables is required.\n' >&2
    exit 1
}

# Docker owns DOCKER-USER. Refuse to create an unrelated replacement when
# Docker is unavailable, because that would give a false sense of protection.
iptables --wait --list "$docker_chain" >/dev/null 2>&1 || {
    printf 'ERROR: Docker DOCKER-USER chain is unavailable.\n' >&2
    exit 1
}

iptables --wait --new-chain "$chain" 2>/dev/null || true

# Place a fail-closed terminal rule first, then insert the allowed cases ahead
# of it. If a later command fails, new PostgreSQL connections remain blocked.
iptables --wait --flush "$chain"
iptables --wait --append "$chain" --match conntrack --ctstate NEW --jump DROP
iptables --wait --insert "$chain" 1 --match conntrack \
    --ctstate ESTABLISHED,RELATED --jump ACCEPT
iptables --wait --insert "$chain" 2 --match conntrack --ctstate NEW \
    --match limit --limit "$rate" --limit-burst "$burst" --jump RETURN
iptables --wait --append "$chain" --jump RETURN

# Remove stale or duplicate managed jumps before inserting one canonical jump.
while iptables --wait --check "$docker_chain" --protocol tcp \
    --destination-port "$postgres_port" --jump "$chain" 2>/dev/null; do
    iptables --wait --delete "$docker_chain" --protocol tcp \
        --destination-port "$postgres_port" --jump "$chain"
done
iptables --wait --insert "$docker_chain" 1 --protocol tcp \
    --destination-port "$postgres_port" --jump "$chain"

# Verify the complete policy. A missing assertion is a service failure.
iptables --wait --check "$docker_chain" --protocol tcp \
    --destination-port "$postgres_port" --jump "$chain"
iptables --wait --check "$chain" --match conntrack \
    --ctstate ESTABLISHED,RELATED --jump ACCEPT
iptables --wait --check "$chain" --match conntrack --ctstate NEW \
    --match limit --limit "$rate" --limit-burst "$burst" --jump RETURN
iptables --wait --check "$chain" --match conntrack --ctstate NEW --jump DROP

printf 'Apex PostgreSQL Docker ingress guard is active.\n'
