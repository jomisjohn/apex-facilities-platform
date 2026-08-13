import json
import os
import shutil
import subprocess
from pathlib import Path


def production_environment() -> dict[str, str]:
    return {
        **os.environ,
        "APEX_WEB_DOMAIN": "localhost",
        "APEX_DB_NAME": "apex_facilities",
        "APEX_DB_ADMIN_USER": "apex_admin",
        "APEX_DB_ADMIN_PASSWORD": "validation-admin-password-0001",
        "APEX_PREVIEW_ALIAS": "preview99",
        "APEX_PREVIEW_PASSWORD": "validation-preview-password-0002",
    }


def docker_command() -> str:
    discovered = shutil.which("docker")
    if discovered:
        return discovered
    windows_docker = Path(r"C:\Program Files\Docker\Docker\resources\bin\docker.exe")
    if windows_docker.is_file():
        return str(windows_docker)
    raise FileNotFoundError("Docker CLI is required for production Compose validation.")


def resolved_compose(repo_root: Path) -> dict:
    result = subprocess.run(
        [
            docker_command(),
            "compose",
            "-f",
            "deploy/compose.production.yaml",
            "config",
            "--format",
            "json",
        ],
        cwd=repo_root,
        env=production_environment(),
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def test_production_compose_resolves(repo_root: Path) -> None:
    config = resolved_compose(repo_root)
    assert set(config["services"]) == {
        "app",
        "caddy",
        "database",
        "migrations",
        "preview-workspace",
    }


def test_only_caddy_publishes_host_ports(repo_root: Path) -> None:
    services = resolved_compose(repo_root)["services"]
    assert "ports" not in services["database"]
    assert "ports" not in services["app"]
    assert "ports" not in services["migrations"]
    assert "ports" not in services["preview-workspace"]
    published = {(port["published"], port["target"]) for port in services["caddy"]["ports"]}
    assert published == {("80", 80), ("443", 443)} or published == {(80, 80), (443, 443)}


def test_database_network_is_internal_and_separated(repo_root: Path) -> None:
    config = resolved_compose(repo_root)
    services = config["services"]
    data_network = "data"
    web_network = "web"
    assert config["networks"][data_network]["internal"] is True
    assert set(services["database"]["networks"]) == {data_network}
    assert set(services["caddy"]["networks"]) == {web_network}
    assert set(services["app"]["networks"]) == {data_network, web_network}


def test_containers_have_health_and_hardening(repo_root: Path) -> None:
    services = resolved_compose(repo_root)["services"]
    for name in ("database", "app", "caddy"):
        assert services[name].get("healthcheck"), name
        assert "no-new-privileges:true" in services[name].get("security_opt", []), name
        assert services[name]["restart"] == "unless-stopped"
    for name in ("app", "migrations", "preview-workspace"):
        assert services[name]["read_only"] is True


def test_app_never_receives_database_admin_credentials(repo_root: Path) -> None:
    services = resolved_compose(repo_root)["services"]
    app_environment = services["app"]["environment"]
    assert "APEX_DB_ADMIN_USER" not in app_environment
    assert "APEX_DB_ADMIN_PASSWORD" not in app_environment
    assert app_environment["APEX_PREVIEW_ALIAS"] == "preview99"
    assert app_environment["APEX_PREVIEW_PASSWORD"] == "validation-preview-password-0002"


def test_caddy_routes_only_to_streamlit_and_sets_security_headers(repo_root: Path) -> None:
    caddyfile = (repo_root / "deploy" / "caddy" / "Caddyfile").read_text("utf-8")
    assert "reverse_proxy app:8501" in caddyfile
    assert "X-Content-Type-Options nosniff" in caddyfile
    assert "Referrer-Policy strict-origin-when-cross-origin" in caddyfile
    assert "reverse_proxy database" not in caddyfile


def test_production_examples_contain_placeholders_not_real_infrastructure(repo_root: Path) -> None:
    example = (repo_root / ".env.production.example").read_text("utf-8")
    assert "replace-with-" in example
    assert "example.edu" in example
    assert "127.0.0.1" not in example
    assert "APEX_DB_ADMIN_PASSWORD=" in example
    assert "APEX_PREVIEW_PASSWORD=" in example
