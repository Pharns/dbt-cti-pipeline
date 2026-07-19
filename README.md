# CTI Behavioral-Analytics Pipeline (dbt + DuckDB)

A small, self-contained data pipeline that ingests live cyber threat intelligence (CTI)
feeds, transforms them with **dbt**, and produces **behavioral-analytics tables** for threat
detection and lead generation — built on **DuckDB** so it runs locally with no cloud setup.

## What it does

```
live CTI feeds (abuse.ch URLhaus + ThreatFox)
        │   scripts/load_feeds.py  →  DuckDB (raw tables)
        ▼
staging models (dbt)   →  clean, typed, common IOC schema (one per feed)
        ▼
int_iocs_unioned       →  both feeds normalized into one table (multi-source correlation)
        ▼
behavioral-analytics marts (dbt):
    • mart_ioc_by_family     — IOC volume + time span per malware/threat family
    • mart_daily_ioc_volume  — daily volume with a 7-day baseline (anomaly-detection-ready)
    • mart_cross_feed_iocs   — IOCs corroborated across >1 feed = higher-confidence leads
```

Each model is tested (`not_null`, `unique`, `accepted_values`) and documented; `dbt docs`
generates the full lineage DAG.

## Verified run

A live run against the feeds (results vary — the feeds are rolling recent-activity windows):

| Model | Rows | What it is |
|---|---|---|
| `stg_urlhaus` | ~20,700 | Cleaned URLhaus URLs |
| `stg_threatfox` | ~4,000 | Cleaned ThreatFox IOCs |
| `int_iocs_unioned` | ~24,700 | Both feeds, one normalized table |
| `mart_ioc_by_family` | ~60 | Volume + span per threat family (Cobalt Strike, Remcos, AsyncRAT, Vidar…) |
| `mart_daily_ioc_volume` | ~770 | Daily volume + 7-day baseline per IOC type |
| `mart_cross_feed_iocs` | ~20 | IOCs corroborated across **both** feeds (higher-confidence leads) |

`dbt run` → 6 models built · `dbt test` → **14/14 tests pass**.

> **Data note:** URLhaus reports a coarse `threat` category (e.g. `malware_download`) rather than
> a named malware family, so that value dominates `mart_ioc_by_family` by volume. ThreatFox
> supplies the named families. This is a real characteristic of the feeds, kept visible rather
> than filtered away — the point is honest modeling of the source data.

## Why this design

- **Staging → intermediate → marts** is the standard dbt layering: raw data stays 1:1 with the
  source, transformations are modular and testable, and the marts are the analysis-ready tables.
- **Multi-source correlation**: unioning independent feeds surfaces IOCs corroborated by more than
  one source — a stronger lead than a single sighting.
- **Anomaly-ready**: daily volume against a trailing baseline is the simplest honest surface for
  spotting abnormal activity in a signal stream.

## Run it (≈5 minutes)

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# 1. ingest live CTI feeds into DuckDB
python scripts/load_feeds.py

# 2. build + test the dbt models
dbt run   --profiles-dir .
dbt test  --profiles-dir .

# 3. see the lineage DAG + docs
dbt docs generate --profiles-dir .
dbt docs serve    --profiles-dir .
```

## Stack
- **dbt Core** (dbt-duckdb adapter) — transformation, testing, documentation, DAG
- **DuckDB** — local analytical database, zero-config
- **Python** — feed ingestion (`requests` + `csv` → DuckDB)

## Data sources
- [abuse.ch URLhaus](https://urlhaus.abuse.ch/) — recent malicious URLs
- [abuse.ch ThreatFox](https://threatfox.abuse.ch/) — recent IOCs (IP / domain / hash) with malware family

Both are free, no-auth, community CTI feeds. This project uses only public data.

---
*Built as a hands-on dbt project modeling a real CTI → behavioral-analytics workflow.*
