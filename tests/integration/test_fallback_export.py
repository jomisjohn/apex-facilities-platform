import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path

import pandas as pd
import pytest
from numpy import ndarray
from sqlalchemy import URL, create_engine, text

from scripts.export_fallback_data import EXPORT_VIEWS, read_local_env, setting, write_csv


pytestmark = pytest.mark.fallback
EXPECTED_DATASETS = {view.file_stem: view for view in EXPORT_VIEWS}
FORBIDDEN_COLUMN_PARTS = {
    "address",
    "email",
    "first_name",
    "grade",
    "last_name",
    "password",
    "phone",
    "secret",
    "student_id",
    "submission",
    "token",
    "username",
}
SECRET_PATTERNS = (
    re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    re.compile(r"postgres(?:ql)?(?:\+\w+)?://[^\s:/]+:[^\s@]+@", re.IGNORECASE),
)


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


@pytest.fixture(scope="module")
def fallback_exports(repo_root: Path, tmp_path_factory):
    if os.getenv("APEX_RUN_FALLBACK_TESTS") != "1":
        pytest.skip("Set APEX_RUN_FALLBACK_TESTS=1 to validate generated fallback files.")
    env_file = repo_root / ".env"
    if not env_file.exists() and not os.getenv("APEX_DB_ADMIN_PASSWORD"):
        pytest.skip("Fallback generation requires local database settings in environment or .env.")

    output_roots = [tmp_path_factory.mktemp("fallback_a"), tmp_path_factory.mktemp("fallback_b")]
    for output_root in output_roots:
        subprocess.run(
            [
                sys.executable,
                str(repo_root / "scripts" / "export_fallback_data.py"),
                "--snapshot-label",
                "validation-2026.1",
                "--output-root",
                str(output_root),
                "--env-file",
                str(env_file),
            ],
            cwd=repo_root,
            check=True,
            capture_output=True,
            text=True,
        )
    snapshots = [root / "validation-2026.1" for root in output_roots]
    manifests = [json.loads((snapshot / "manifest.json").read_text("utf-8")) for snapshot in snapshots]
    return snapshots, manifests, env_file


def manifest_datasets(manifest: dict) -> dict[str, dict]:
    return {entry["dataset_name"]: entry for entry in manifest["datasets"]}


def test_manifest_is_complete_and_safe(fallback_exports) -> None:
    snapshots, manifests, _ = fallback_exports
    manifest = manifests[0]
    assert manifest["manifest_schema_version"] == "1.0"
    assert manifest["snapshot_label"] == "validation-2026.1"
    assert manifest["synthetic_data"] is True
    assert manifest["contains_personal_information"] is False
    assert manifest["formats"] == ["csv", "parquet"]
    datasets = manifest_datasets(manifest)
    assert set(datasets) == set(EXPECTED_DATASETS)
    assert len(manifest["datasets"]) == len(EXPORT_VIEWS) == 10

    forbidden_manifest_keys = {"host", "password", "port", "username", "database_url"}
    assert forbidden_manifest_keys.isdisjoint(manifest)
    for name, entry in datasets.items():
        expected = EXPECTED_DATASETS[name]
        assert entry["source_view"] == expected.source_view
        assert entry["sort_columns"] == list(expected.order_by)
        assert entry["row_count"] > 0
        assert entry["column_count"] == len(entry["columns"]) > 0
        for file_entry in entry["files"].values():
            relative = Path(file_entry["path"])
            assert not relative.is_absolute() and ".." not in relative.parts
            assert (snapshots[0] / relative).is_file()


def test_manifest_checksums_and_sizes_match_files(fallback_exports) -> None:
    snapshots, manifests, _ = fallback_exports
    for snapshot, manifest in zip(snapshots, manifests, strict=True):
        for entry in manifest["datasets"]:
            for file_entry in entry["files"].values():
                path = snapshot / file_entry["path"]
                assert path.stat().st_size == file_entry["bytes"]
                assert re.fullmatch(r"[0-9a-f]{64}", file_entry["sha256"])
                assert file_sha256(path) == file_entry["sha256"]


def test_exports_are_byte_deterministic(fallback_exports) -> None:
    snapshots, manifests, _ = fallback_exports
    comparable_manifests = [
        {key: value for key, value in manifest.items() if key != "exported_at_utc"}
        for manifest in manifests
    ]
    assert comparable_manifests[0] == comparable_manifests[1]
    first, second = map(manifest_datasets, manifests)
    for name in EXPECTED_DATASETS:
        for file_format in ("csv", "parquet"):
            first_path = snapshots[0] / first[name]["files"][file_format]["path"]
            second_path = snapshots[1] / second[name]["files"][file_format]["path"]
            assert file_sha256(first_path) == file_sha256(second_path), (name, file_format)


def test_csv_and_parquet_have_identical_rows_columns_and_values(
    fallback_exports, tmp_path: Path
) -> None:
    snapshots, manifests, _ = fallback_exports
    datasets = manifest_datasets(manifests[0])
    for name, entry in datasets.items():
        csv_path = snapshots[0] / entry["files"]["csv"]["path"]
        parquet_path = snapshots[0] / entry["files"]["parquet"]["path"]
        csv_frame = pd.read_csv(csv_path)
        parquet_frame = pd.read_parquet(parquet_path)
        assert list(csv_frame.columns) == list(parquet_frame.columns)
        assert csv_frame.shape == parquet_frame.shape == (
            entry["row_count"],
            entry["column_count"],
        )

        for column in parquet_frame.columns:
            parquet_frame[column] = parquet_frame[column].map(
                lambda value: value.tolist() if isinstance(value, ndarray) else value
            )
        parquet_as_csv = tmp_path / f"{name}.csv"
        write_csv(parquet_frame, parquet_as_csv)
        assert csv_path.read_bytes() == parquet_as_csv.read_bytes(), name


def test_export_schema_and_rows_match_stable_database_views(fallback_exports) -> None:
    _, manifests, env_file = fallback_exports
    local_env = read_local_env(env_file)
    database_url = URL.create(
        drivername="postgresql+psycopg",
        username=setting("APEX_DB_ADMIN_USER", local_env, "apex_admin"),
        password=setting("APEX_DB_ADMIN_PASSWORD", local_env),
        host=setting("APEX_DB_HOST", local_env, "127.0.0.1"),
        port=int(setting("APEX_DB_PORT", local_env, "5432")),
        database=setting("APEX_DB_NAME", local_env, "apex_facilities"),
    )
    engine = create_engine(database_url, pool_pre_ping=True)
    try:
        with engine.connect() as connection:
            for entry in manifests[0]["datasets"]:
                source_view = entry["source_view"]
                row_count = connection.execute(text(f"SELECT count(*) FROM {source_view}"))
                assert row_count.scalar_one() == entry["row_count"]
                columns = pd.read_sql_query(text(f"SELECT * FROM {source_view} LIMIT 0"), connection)
                assert list(columns.columns) == [column["name"] for column in entry["columns"]]
    finally:
        engine.dispose()


def test_fallback_files_contain_no_secret_or_pii_fields(fallback_exports) -> None:
    snapshots, manifests, env_file = fallback_exports
    local_env = read_local_env(env_file)
    password = setting("APEX_DB_ADMIN_PASSWORD", local_env)
    assert len(password) >= 16

    for snapshot, manifest in zip(snapshots, manifests, strict=True):
        manifest_text = (snapshot / "manifest.json").read_text("utf-8")
        assert password not in manifest_text
        assert not any(pattern.search(manifest_text) for pattern in SECRET_PATTERNS)
        for entry in manifest["datasets"]:
            column_names = {column["name"].lower() for column in entry["columns"]}
            assert not any(
                forbidden in column
                for column in column_names
                for forbidden in FORBIDDEN_COLUMN_PARTS
            ), entry["dataset_name"]
            for file_entry in entry["files"].values():
                raw = (snapshot / file_entry["path"]).read_bytes()
                assert password.encode() not in raw
