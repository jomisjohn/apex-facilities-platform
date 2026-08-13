import re
import subprocess
from pathlib import Path


FORBIDDEN_TRACKED_NAMES = {".env", "secrets.toml"}
FORBIDDEN_SUFFIXES = {".pem", ".key", ".p12", ".pfx", ".dump"}
SECRET_PATTERNS = (
    re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    re.compile(r"postgres(?:ql)?(?:\+\w+)?://[^\s:/]+:[^\s@]+@", re.IGNORECASE),
)


def public_candidate_files(repo_root: Path) -> list[Path]:
    output = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard"],
        cwd=repo_root,
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    return [repo_root / item for item in output.splitlines()]


def test_no_secret_or_private_artifact_is_tracked(repo_root: Path) -> None:
    violations = []
    for path in public_candidate_files(repo_root):
        relative = path.relative_to(repo_root)
        if path.name in FORBIDDEN_TRACKED_NAMES or path.suffix.lower() in FORBIDDEN_SUFFIXES:
            violations.append(str(relative))
        if relative.parts and relative.parts[0] in {"private", "backups"}:
            violations.append(str(relative))
    assert not violations, f"Sensitive paths are tracked: {sorted(set(violations))}"


def test_tracked_text_has_no_private_key_or_credential_url(repo_root: Path) -> None:
    violations = []
    for path in public_candidate_files(repo_root):
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        if any(pattern.search(text) for pattern in SECRET_PATTERNS):
            violations.append(str(path.relative_to(repo_root)))
    assert not violations, f"Credential-like content found in: {violations}"
