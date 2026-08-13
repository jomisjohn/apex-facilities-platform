import json
import os
import subprocess
from pathlib import Path

from tests.unit.test_production_config import docker_command


def tls_environment() -> dict[str, str]:
    return {
        **os.environ,
        "APEX_WEB_DOMAIN": "localhost",
        "APEX_DB_DOMAIN": "db.validation.test",
        "APEX_DB_TLS_SOURCE_DIR": str(Path.cwd() / "private-test-certificates"),
        "APEX_DB_BIND_ADDRESS": "127.0.0.1",
        "APEX_DB_TLS_PORT": "5432",
        "APEX_DB_ADMIN_PASSWORD": "validation-admin-password-0001",
        "APEX_PREVIEW_ALIAS": "preview99",
        "APEX_PREVIEW_PASSWORD": "validation-preview-password-0002",
    }


def resolved_tls_compose(repo_root: Path) -> dict:
    result = subprocess.run(
        [
            docker_command(),
            "compose",
            "-f",
            "deploy/compose.production.yaml",
            "-f",
            "deploy/compose.database-tls.yaml",
            "config",
            "--format",
            "json",
        ],
        cwd=repo_root,
        env=tls_environment(),
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def test_tls_overlay_is_loopback_only_by_default(repo_root: Path) -> None:
    database = resolved_tls_compose(repo_root)["services"]["database"]
    assert database["ports"] == [
        {
            "mode": "ingress",
            "target": 5432,
            "published": "5432",
            "protocol": "tcp",
            "host_ip": "127.0.0.1",
        }
    ]
    assert "database-ingress" in database["networks"]


def test_postgresql_requires_tls_12_scram_and_remote_hba(repo_root: Path) -> None:
    database = resolved_tls_compose(repo_root)["services"]["database"]
    command = " ".join(database["command"])
    assert "ssl=on" in command
    assert "ssl_min_protocol_version=TLSv1.2" in command
    assert "password_encryption=scram-sha-256" in command
    assert "hba_file=/etc/postgresql/pg_hba.remote.conf" in command


def test_remote_hba_is_first_match_fail_closed(repo_root: Path) -> None:
    lines = [
        line.split("#", 1)[0].strip()
        for line in (repo_root / "deploy/database/pg_hba.remote.conf").read_text("utf-8").splitlines()
        if line.split("#", 1)[0].strip()
    ]
    assert lines[0].startswith("local") and lines[0].endswith("scram-sha-256")
    assert lines[1].startswith("hostssl   apex_facilities  +apex_workspace_member")
    assert lines[2].startswith("hostssl   apex_facilities  +apex_workspace_member")
    assert lines[3].startswith("hostnossl all") and lines[3].endswith("reject")
    assert lines[4].startswith("hostnossl all") and lines[4].endswith("reject")
    assert lines[5].startswith("hostssl   all") and lines[5].endswith("reject")
    assert lines[6].startswith("hostssl   all") and lines[6].endswith("reject")


def test_admin_automation_uses_socket_and_app_has_no_admin_secret(repo_root: Path) -> None:
    services = resolved_tls_compose(repo_root)["services"]
    for name in ("migrations", "preview-workspace"):
        assert services[name]["environment"]["PGHOST"] == "/var/run/postgresql"
        assert services[name]["environment"]["PGSSLMODE"] == "disable"
    app_environment = services["app"]["environment"]
    assert app_environment["APEX_DB_SSLMODE"] == "require"
    assert "APEX_DB_ADMIN_PASSWORD" not in app_environment


def test_certificate_material_is_external_and_key_destination_is_restricted(repo_root: Path) -> None:
    services = resolved_tls_compose(repo_root)["services"]
    source_mount = next(
        mount for mount in services["tls-prepare"]["volumes"] if mount["target"] == "/certificate-source"
    )
    assert source_mount["read_only"] is True
    script = (repo_root / "deploy/database/prepare-tls.sh").read_text("utf-8")
    assert 'chmod 0600 "$temporary_key"' in script
    assert 'chmod 0644 "$temporary_certificate"' in script
    assert "openssl x509" in script and "-checkhost" in script and "-checkend" in script
    assert "certificate_key_hash" in script and "private_key_hash" in script


def test_no_certificate_or_private_key_is_tracked(repo_root: Path) -> None:
    output = subprocess.run(
        ["git", "ls-files"], cwd=repo_root, check=True, capture_output=True, text=True
    ).stdout.splitlines()
    forbidden = {"fullchain.pem", "privkey.pem", "server.crt", "server.key"}
    assert not [path for path in output if Path(path).name in forbidden]


def test_student_local_guide_requires_verified_tls_and_safe_fallback(repo_root: Path) -> None:
    local_guide = (repo_root / "apps/aida1145/LOCAL-DEVELOPMENT.md").read_text("utf-8")
    deployment_guide = (repo_root / "deploy/README.md").read_text("utf-8")
    assert 'sslmode = "verify-full"' in local_guide
    assert "Use the assigned hostname, not a raw IP address" in local_guide
    assert "Do not weaken TLS or accept an untrusted certificate" in local_guide
    assert "DBeaver Community is sufficient; no paid edition is required" in local_guide
    assert "Test outbound port 5432 from the campus network" in deployment_guide
    assert "CSV/Parquet fallback" in deployment_guide
    assert "does not assess database behaviour" in deployment_guide


def test_measured_capacity_controls_are_rendered(repo_root: Path) -> None:
    services = resolved_tls_compose(repo_root)["services"]
    database_command = " ".join(services["database"]["command"])
    assert "max_connections=100" in database_command
    assert "reserved_connections=5" in database_command
    assert "superuser_reserved_connections=3" in database_command
    entrypoint = (repo_root / "deploy/app/entrypoint.py").read_text("utf-8")
    example = (repo_root / "apps/aida1145/.streamlit/secrets.toml.example").read_text("utf-8")
    for setting in ("pool_size = 1", "max_overflow = 0", "pool_timeout = 10"):
        assert setting in entrypoint
        assert setting in example


def test_acme_overlay_is_profile_gated_and_certificate_export_is_atomic(repo_root: Path) -> None:
    environment = tls_environment() | {"APEX_ACME_EMAIL": "validation@example.edu"}
    result = subprocess.run(
        [
            docker_command(),
            "compose",
            "-f",
            "deploy/compose.production.yaml",
            "-f",
            "deploy/compose.database-acme.yaml",
            "--profile",
            "database-acme",
            "config",
            "--format",
            "json",
        ],
        cwd=repo_root,
        env=environment,
        check=True,
        capture_output=True,
        text=True,
    )
    service = json.loads(result.stdout)["services"]["database-certbot"]
    assert service["profiles"] == ["database-acme"]
    assert service["read_only"] is True
    script = (repo_root / "deploy/database/certbot-db.sh").read_text("utf-8")
    assert "--authenticator webroot" in script
    assert "--deploy-hook /usr/local/bin/certbot-export-db" in script
    assert 'chmod 0600 "$temporary_key"' in script
    assert 'mv -f "$temporary_key" "$certificate_export/privkey.pem"' in script
