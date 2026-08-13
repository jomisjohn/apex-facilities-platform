"""Export the stable Apex student views as CSV and Parquet fallback files."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import pandas as pd
from numpy import ndarray
from sqlalchemy import URL, create_engine, text


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = REPOSITORY_ROOT / "data" / "fallback"
SNAPSHOT_LABEL_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._-]{0,63}$")
SYNTHETIC_NOTICE = (
    "Apex is a fictional facilities maintenance platform. These deterministic "
    "records are synthetic learning data and contain no real customer, employee, "
    "student, address, grade, submission, or production-system information."
)


@dataclass(frozen=True)
class ExportView:
    source_view: str
    file_stem: str
    order_by: tuple[str, ...]


EXPORT_VIEWS = (
    ExportView("shared_facilities.v_facility_profile", "facility_profile", ("facility_id",)),
    ExportView("shared_readiness.v_readiness_status", "readiness_status", ("mobilization_id",)),
    ExportView("shared_operations.v_service_visit_detail", "service_visit_detail", ("service_visit_id",)),
    ExportView("shared_operations.v_work_order_asset_detail", "work_order_asset_detail", ("work_order_id",)),
    ExportView("shared_quality.v_facility_quality_summary", "facility_quality_summary", ("facility_id",)),
    ExportView("shared_finance.v_facility_financial_summary", "facility_financial_summary", ("facility_id",)),
    ExportView("shared_supply.v_inventory_movement_detail", "inventory_movement_detail", ("inventory_transaction_id",)),
    ExportView("shared_insights.v_client_performance_summary", "client_performance_summary", ("client_id",)),
    ExportView("shared_spatial.v_service_route_summary", "service_route_summary", ("service_visit_id",)),
    ExportView("shared_research.v_lab_data_package_catalog", "lab_data_package_catalog", ("course_code", "lab_number", "data_package_id")),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export the ten stable Apex student views to CSV and Parquet."
    )
    parser.add_argument(
        "--snapshot-label",
        default="apex-2026.1",
        help="Version label written into the manifest and output folder.",
    )
    parser.add_argument(
        "--output-root",
        type=Path,
        default=DEFAULT_OUTPUT,
        help="Generated output root (default: data/fallback).",
    )
    parser.add_argument(
        "--env-file",
        type=Path,
        default=REPOSITORY_ROOT / ".env",
        help="Local environment file used only when matching process variables are unset.",
    )
    return parser.parse_args()


def read_local_env(path: Path) -> dict[str, str]:
    """Read the small local KEY=VALUE file without logging any values."""
    if not path.exists():
        return {}
    values: dict[str, str] = {}
    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            raise ValueError(f"Invalid environment entry on line {line_number} of {path}.")
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def setting(name: str, local_env: dict[str, str], default: str | None = None) -> str:
    value = os.environ.get(name) or local_env.get(name) or default
    if value is None or value == "":
        raise ValueError(f"Set {name} in the process environment or local .env file.")
    return value


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def column_manifest(frame: pd.DataFrame) -> list[dict[str, str]]:
    return [{"name": str(column), "export_type": str(frame[column].dtype)} for column in frame.columns]


def normalize_collection_values(frame: pd.DataFrame) -> pd.DataFrame:
    """Represent PostgreSQL array fields consistently in both file formats."""
    normalized = frame.copy()
    for column in normalized.columns:
        if normalized[column].map(lambda value: isinstance(value, (list, tuple, ndarray))).any():
            normalized[column] = normalized[column].map(
                lambda value: json.dumps(
                    value.tolist() if isinstance(value, ndarray) else value,
                    ensure_ascii=False,
                    separators=(",", ":"),
                )
                if isinstance(value, (list, tuple, ndarray))
                else value
            )
    return normalized


def write_csv(frame: pd.DataFrame, path: Path) -> None:
    frame.to_csv(
        path,
        index=False,
        encoding="utf-8",
        lineterminator="\n",
        quoting=csv.QUOTE_MINIMAL,
        date_format="%Y-%m-%dT%H:%M:%S%z",
    )


def write_parquet(frame: pd.DataFrame, path: Path) -> None:
    frame.to_parquet(
        path,
        engine="pyarrow",
        index=False,
        compression="zstd",
        version="2.6",
    )


def file_entry(path: Path, snapshot_directory: Path) -> dict[str, Any]:
    return {
        "path": path.relative_to(snapshot_directory).as_posix(),
        "bytes": path.stat().st_size,
        "sha256": sha256(path),
    }


def export() -> int:
    args = parse_args()
    if not SNAPSHOT_LABEL_PATTERN.fullmatch(args.snapshot_label):
        raise ValueError(
            "Snapshot label must begin with a lowercase letter or number and contain "
            "only lowercase letters, numbers, periods, underscores, or hyphens."
        )

    local_env = read_local_env(args.env_file.resolve())
    database_url = URL.create(
        drivername="postgresql+psycopg",
        username=setting("APEX_DB_ADMIN_USER", local_env, "apex_admin"),
        password=setting("APEX_DB_ADMIN_PASSWORD", local_env),
        host=setting("APEX_DB_HOST", local_env, "127.0.0.1"),
        port=int(setting("APEX_DB_PORT", local_env, "5432")),
        database=setting("APEX_DB_NAME", local_env, "apex_facilities"),
    )
    snapshot_directory = args.output_root.resolve() / args.snapshot_label
    snapshot_directory.mkdir(parents=True, exist_ok=True)

    exported_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    manifest: dict[str, Any] = {
        "manifest_schema_version": "1.0",
        "snapshot_label": args.snapshot_label,
        "exported_at_utc": exported_at,
        "database_name": database_url.database,
        "source_interface": "stable student-facing PostgreSQL views",
        "synthetic_data": True,
        "contains_personal_information": False,
        "provenance_notice": SYNTHETIC_NOTICE,
        "formats": ["csv", "parquet"],
        "datasets": [],
    }

    engine = create_engine(database_url, pool_pre_ping=True)
    try:
        with engine.connect().execution_options(isolation_level="REPEATABLE READ") as connection:
            transaction = connection.begin()
            try:
                for view in EXPORT_VIEWS:
                    order_clause = ", ".join(f'"{column}"' for column in view.order_by)
                    query = text(f"SELECT * FROM {view.source_view} ORDER BY {order_clause}")
                    frame = normalize_collection_values(pd.read_sql_query(query, connection))

                    csv_path = snapshot_directory / f"{view.file_stem}.csv"
                    parquet_path = snapshot_directory / f"{view.file_stem}.parquet"
                    write_csv(frame, csv_path)
                    write_parquet(frame, parquet_path)

                    manifest["datasets"].append(
                        {
                            "dataset_name": view.file_stem,
                            "source_view": view.source_view,
                            "row_count": len(frame),
                            "column_count": len(frame.columns),
                            "columns": column_manifest(frame),
                            "sort_columns": list(view.order_by),
                            "files": {
                                "csv": file_entry(csv_path, snapshot_directory),
                                "parquet": file_entry(parquet_path, snapshot_directory),
                            },
                        }
                    )
                transaction.commit()
            except Exception:
                transaction.rollback()
                raise
    finally:
        engine.dispose()

    manifest_path = snapshot_directory / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    total_bytes = sum(path.stat().st_size for path in snapshot_directory.iterdir() if path.is_file())
    print(
        f"Exported {len(manifest['datasets'])} synthetic Apex datasets to "
        f"{snapshot_directory} ({total_bytes:,} bytes)."
    )
    print(f"Manifest: {manifest_path}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(export())
    except Exception as error:
        print(f"Export failed: {error}", file=sys.stderr)
        sys.exit(1)
