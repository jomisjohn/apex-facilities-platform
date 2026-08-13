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


def test_database_deployment_entrypoints_are_executable_in_git(repo_root: Path) -> None:
    result = subprocess.run(
        ["git", "ls-files", "--stage", "--", "deploy/database"],
        cwd=repo_root,
        check=True,
        capture_output=True,
        text=True,
    )
    modes = {
        line.split(maxsplit=3)[3]: line.split(maxsplit=1)[0]
        for line in result.stdout.splitlines()
    }
    executable_scripts = {
        "deploy/database/certbot-db.sh",
        "deploy/database/certbot-export-db",
        "deploy/database/manage-db-certificate.sh",
        "deploy/database/prepare-tls.sh",
        "deploy/database/provision-preview.sh",
        "deploy/database/refresh-db-tls.sh",
        "deploy/database/run-migrations.sh",
    }
    assert {path: modes[path] for path in executable_scripts} == {
        path: "100755" for path in executable_scripts
    }
    assert modes["deploy/database/pg_hba.remote.conf"] == "100644"


def test_systemd_certificate_renewal_is_persistent_hardened_and_secret_free(
    repo_root: Path,
) -> None:
    systemd = repo_root / "deploy/systemd"
    service = (systemd / "apex-db-certificate-renew.service").read_text("utf-8")
    timer = (systemd / "apex-db-certificate-renew.timer").read_text("utf-8")
    installer = (systemd / "install-certificate-renewal.sh").read_text("utf-8")

    assert "OnCalendar=daily" in timer
    assert "Persistent=true" in timer
    assert "RandomizedDelaySec=2h" in timer
    assert "WantedBy=timers.target" in timer
    assert "Unit=apex-db-certificate-renew.service" in timer

    command = (
        "ExecStart=/opt/apex-facilities-platform/deploy/database/"
        "manage-db-certificate.sh renew /opt/apex-facilities-platform/.env.production"
    )
    assert command in service
    assert "Type=oneshot" in service
    assert "User=root" in service and "Group=root" in service
    assert "UMask=0077" in service
    assert "NoNewPrivileges=true" in service
    assert "PrivateTmp=true" in service
    assert "ProtectHome=true" in service
    assert "Environment=" not in service
    assert "EnvironmentFile=" not in service

    assert "test -x \"$repository/deploy/database/manage-db-certificate.sh\"" in installer
    assert "test -f \"$repository/.env.production\"" in installer
    assert "install -o root -g root -m 0644" in installer
    assert "systemctl enable --now apex-db-certificate-renew.timer" in installer
    assert "systemctl start apex-db-certificate-renew.service" in installer

    result = subprocess.run(
        ["git", "ls-files", "--stage", "--", "deploy/systemd"],
        cwd=repo_root,
        check=True,
        capture_output=True,
        text=True,
    )
    modes = {
        line.split(maxsplit=3)[3]: line.split(maxsplit=1)[0]
        for line in result.stdout.splitlines()
    }
    assert modes == {
        "deploy/systemd/apex-db-certificate-renew.service": "100644",
        "deploy/systemd/apex-db-certificate-renew.timer": "100644",
        "deploy/systemd/install-certificate-renewal.sh": "100755",
    }

    combined = service + timer + installer
    assert "PRIVATE KEY" not in combined
    assert "APEX_DB_ADMIN_PASSWORD=" not in combined
    assert "APEX_PREVIEW_PASSWORD=" not in combined
