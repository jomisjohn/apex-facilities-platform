import subprocess
from pathlib import Path


def test_postgres_ingress_guard_is_scoped_idempotent_and_rate_limited(repo_root: Path) -> None:
    script = (repo_root / "deploy/firewall/apply-postgres-ingress.sh").read_text("utf-8")
    assert "chain=APEX-POSTGRES-INGRESS" in script
    assert "docker_chain=DOCKER-USER" in script
    assert "postgres_port=5432" in script
    assert "rate=150/second" in script
    assert "burst=180" in script
    assert '--ctstate ESTABLISHED,RELATED --jump ACCEPT' in script
    assert '--ctstate NEW --jump DROP' in script
    assert '--limit "$rate" --limit-burst "$burst" --jump RETURN' in script
    assert 'while iptables --wait --check "$docker_chain"' in script
    assert 'iptables --wait --flush "$chain"' in script
    assert '--destination-port "$postgres_port" --jump "$chain"' in script
    assert "--dports" not in script
    assert "--policy" not in script


def test_postgres_ingress_service_runs_after_docker_with_required_hardening(
    repo_root: Path,
) -> None:
    service = (repo_root / "deploy/systemd/apex-postgres-ingress.service").read_text("utf-8")
    assert "Requires=docker.service" in service
    assert "After=docker.service network-online.target" in service
    assert "PartOf=docker.service" in service
    assert "WantedBy=docker.service" in service
    assert "Type=oneshot" in service and "RemainAfterExit=yes" in service
    assert "User=root" in service and "Group=root" in service
    assert "NoNewPrivileges=true" in service
    assert "ProtectSystem=strict" in service
    assert "CapabilityBoundingSet=CAP_NET_ADMIN" in service
    assert (
        "ExecStart=/opt/apex-facilities-platform/deploy/firewall/"
        "apply-postgres-ingress.sh"
    ) in service


def test_postgres_ingress_installer_fails_closed_and_verifies_kernel_rules(
    repo_root: Path,
) -> None:
    installer = (repo_root / "deploy/firewall/install-postgres-ingress.sh").read_text("utf-8")
    assert 'test "$(id -u)" -eq 0' in installer
    assert 'test -x "$guard"' in installer
    assert "systemctl is-active --quiet docker.service" in installer
    assert "iptables --wait --list DOCKER-USER" in installer
    assert "install -o root -g root -m 0644" in installer
    assert "systemctl restart apex-postgres-ingress.service" in installer
    assert "systemctl is-active --quiet apex-postgres-ingress.service" in installer
    assert "--destination-port 5432 --jump APEX-POSTGRES-INGRESS" in installer
    assert "--ctstate NEW --jump DROP" in installer


def test_postgres_ingress_git_modes_and_secret_exclusion(repo_root: Path) -> None:
    result = subprocess.run(
        ["git", "ls-files", "--stage", "--", "deploy/firewall", "deploy/systemd"],
        cwd=repo_root,
        check=True,
        capture_output=True,
        text=True,
    )
    modes = {
        line.split(maxsplit=3)[3]: line.split(maxsplit=1)[0]
        for line in result.stdout.splitlines()
    }
    assert modes["deploy/firewall/apply-postgres-ingress.sh"] == "100755"
    assert modes["deploy/firewall/install-postgres-ingress.sh"] == "100755"
    assert modes["deploy/systemd/apex-postgres-ingress.service"] == "100644"

    content = "".join(
        path.read_text("utf-8")
        for path in (
            repo_root / "deploy/firewall/apply-postgres-ingress.sh",
            repo_root / "deploy/firewall/install-postgres-ingress.sh",
            repo_root / "deploy/systemd/apex-postgres-ingress.service",
        )
    )
    assert "PASSWORD=" not in content
    assert "PRIVATE KEY" not in content
