#!/usr/bin/env python3
"""
load_feeds.py — Ingest real CTI feeds into a local DuckDB, ready for dbt to transform.

Fetches from two free, no-auth abuse.ch feeds:
  - URLhaus  (recent malicious URLs)
  - ThreatFox (recent IOCs: IP / domain / hash, with malware family)

Lands two raw tables in cti.duckdb:  raw_urlhaus, raw_threatfox
Run this ONCE before `dbt run`. Re-run any time to refresh the raw data.

Usage:
    python scripts/load_feeds.py
"""

import csv
import io
import sys
import duckdb
import requests

DB_PATH = "cti.duckdb"
SCHEMA = "raw"  # dbt source() reads from this schema; keep in sync with models/staging/_staging.yml
                # (named 'raw' not 'cti' — the DuckDB file is cti.duckdb, so a 'cti' schema
                #  collides with the database name and DuckDB flags it ambiguous.)

FEEDS = {
    "raw_urlhaus": "https://urlhaus.abuse.ch/downloads/csv_recent/",
    "raw_threatfox": "https://threatfox.abuse.ch/export/csv/recent/",
}


def fetch_csv(url: str) -> list[list[str]]:
    """Fetch an abuse.ch CSV. These feeds prefix rows with '#' comment lines
    and wrap fields in quotes; we filter comments and parse the data rows."""
    resp = requests.get(url, timeout=30, headers={"User-Agent": "cti-pipeline/1.0"})
    resp.raise_for_status()
    lines = [ln for ln in resp.text.splitlines() if ln and not ln.startswith("#")]
    reader = csv.reader(io.StringIO("\n".join(lines)), skipinitialspace=True)
    return [row for row in reader if row]


def load_table(con: duckdb.DuckDBPyConnection, table: str, rows: list[list[str]]) -> None:
    """Load rows into a raw table as generic col0..colN VARCHARs.
    Staging models rename/type them — raw stays intentionally dumb (1:1 with source)."""
    if not rows:
        print(f"  WARN: {table} returned 0 rows (feed empty or format changed) — skipping")
        return
    ncols = max(len(r) for r in rows)
    cols = [f"col{i}" for i in range(ncols)]
    # normalize ragged rows to ncols
    norm = [r + [None] * (ncols - len(r)) for r in rows]
    # Land raw tables in the `cti` schema — matches the dbt source() declaration.
    con.execute(f"CREATE SCHEMA IF NOT EXISTS {SCHEMA}")
    con.execute(f"DROP TABLE IF EXISTS {SCHEMA}.{table}")
    con.execute(f"CREATE TABLE {SCHEMA}.{table} ({', '.join(f'{c} VARCHAR' for c in cols)})")
    con.executemany(
        f"INSERT INTO {SCHEMA}.{table} VALUES ({', '.join(['?'] * ncols)})", norm
    )
    print(f"  loaded {SCHEMA}.{table}: {len(norm)} rows x {ncols} cols")


def main() -> int:
    print(f"Ingesting CTI feeds -> {DB_PATH}")
    con = duckdb.connect(DB_PATH)
    try:
        for table, url in FEEDS.items():
            print(f"- {table}  <-  {url}")
            try:
                rows = fetch_csv(url)
                load_table(con, table, rows)
            except requests.RequestException as e:
                print(f"  ERROR fetching {table}: {e} — leaving prior data in place")
        # quick sanity print
        for table in FEEDS:
            try:
                n = con.execute(f"SELECT count(*) FROM {SCHEMA}.{table}").fetchone()[0]
                print(f"  {SCHEMA}.{table}: {n} rows in DuckDB")
            except duckdb.CatalogException:
                pass
    finally:
        con.close()
    print("Done. Next: dbt seed (if used) then `dbt run` && `dbt test`.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
