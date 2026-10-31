"""Build the SQLite warehouse and export the Power BI star-schema CSVs.

    python scripts/build_database.py

1. loads the raw UCI Online Retail CSV (zipped) into table raw_online_retail
2. runs sql/01 (clean) -> sql/02 (star schema) -> sql/03 (data-quality checks)
3. exports dim_* / fact_sales / data_quality_log to exports/*.csv
"""
import sqlite3
import sys
import time
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).parent))
from sqlrun import named_queries, run_script  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw" / "online_retail.zip"
DB = ROOT / "data" / "sales.db"
SQL = ROOT / "sql"
EXPORT = ROOT / "exports"

FACT_EXPORT_SQL = """SELECT sales_key, invoice_no, date_key, invoice_hour, product_key, customer_key,
                            country, transaction_type, quantity, unit_price, revenue FROM fact_sales"""
EXPORT_TABLES = ["fact_sales", "dim_date", "dim_product", "dim_customer", "dim_country", "data_quality_log"]


def main() -> None:
    t0 = time.time()
    DB.unlink(missing_ok=True)
    con = sqlite3.connect(DB)

    raw = pd.read_csv(RAW, dtype=str, keep_default_na=False)
    raw["Quantity"] = raw["Quantity"].astype(int)
    raw["UnitPrice"] = raw["UnitPrice"].astype(float)
    raw.to_sql("raw_online_retail", con, index=False)
    print(f"loaded raw_online_retail: {len(raw):,} rows")

    for f in ("01_staging_and_cleaning.sql", "02_star_schema.sql"):
        run_script(con, SQL / f)
        print(f"ran {f}")

    print("\nData-quality checks")
    failed = 0
    for name, query in named_queries(SQL / "03_data_quality_checks.sql"):
        check, ok = con.execute(query).fetchone()
        failed += 1 - ok
        print(f"  [{'PASS' if ok else 'FAIL'}] {check}")
    if failed:
        raise SystemExit(f"{failed} data-quality check(s) failed")

    EXPORT.mkdir(exist_ok=True)
    print("\nExports")
    for t in EXPORT_TABLES:
        # fact_sales: drop the timestamp columns (date_key + invoice_hour carry the same info)
        # to keep the CSV well under GitHub's 50 MB warning threshold
        sql = FACT_EXPORT_SQL if t == "fact_sales" else f"SELECT * FROM {t}"
        df = pd.read_sql(sql, con)
        df.to_csv(EXPORT / f"{t}.csv", index=False)
        print(f"  exports/{t}.csv  {len(df):,} rows")
    con.close()
    print(f"\ndone in {time.time() - t0:.1f}s -> {DB.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
