# Apex fallback data

Your lab may provide an Apex CSV or Parquet snapshot when a live PostgreSQL connection is unavailable. The snapshot is a point-in-time copy of the ten stable, student-facing database views. It is not a live connection and it is not synchronized with PostgreSQL.

Changes made later in PostgreSQL, DBeaver or Streamlit do not appear in an existing snapshot. Changes you make to a local CSV or Parquet file do not update PostgreSQL. Treat every supplied snapshot as read-only source data and save your results separately.

## What a snapshot contains

- One CSV and one Parquet file for each stable view.
- A `manifest.json` file with the snapshot label, export time, source view, row count, column names, file size and SHA-256 checksum.
- Only deterministic, synthetic Apex learning data. The files contain no real customer, employee or student information.

CSV files are convenient for inspection and broad tool compatibility. Parquet files preserve data types more accurately and are usually smaller. Use the format named in your lab instructions.

## Verify a supplied snapshot

1. Open `manifest.json` and confirm its `snapshot_label` matches your lab instructions.
2. Find the dataset you were asked to use.
3. Confirm the file name and row count.
4. When your lab asks for an integrity check, calculate the file's SHA-256 checksum and compare it with the manifest.
5. Keep the original supplied file unchanged. Save cleaned data, features and other results only in the location required by your lab.

Do not combine snapshots from different version labels. Use PostgreSQL when a lab assesses database behaviour such as SQL execution, joins in the database, constraints, transactions, permissions, schema changes, workspace writes or live persistence between DBeaver and Streamlit. A fallback snapshot cannot demonstrate those behaviours; use it only when the lab instructions explicitly allow the fallback pathway.

## Load a file in Python

```python
import pandas as pd

facility_profile = pd.read_parquet("facility_profile.parquet")
# Or: pd.read_csv("facility_profile.csv")
```

Use relative paths from your project and never put passwords or personal information in a data file or notebook.

## Generate an instructor or developer snapshot

Generated fallback files are intentionally excluded from Git until a reviewed release is approved. From the repository root, install the pinned export dependencies and run:

```powershell
python -m pip install -r scripts\requirements-export.txt
python scripts\export_fallback_data.py --snapshot-label apex-2026.1
```

The exporter reads local database settings from process environment variables or the ignored `.env` file, performs read-only queries against the ten stable views in one repeatable-read transaction, and writes to `data/fallback/<snapshot-label>/`. It never writes credentials to the manifest or exported files.
