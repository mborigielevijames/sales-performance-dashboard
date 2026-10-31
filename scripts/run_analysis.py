"""Run sql/04_business_analysis.sql and export each result to sql/results/<name>.csv"""
import sqlite3
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).parent))
from sqlrun import named_queries  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "sql" / "results"


def main(show: bool = True) -> dict:
    OUT.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(ROOT / "data" / "sales.db")
    results = {}
    for name, query in named_queries(ROOT / "sql" / "04_business_analysis.sql"):
        df = pd.read_sql(query, con)
        df.to_csv(OUT / f"{name}.csv", index=False)
        results[name] = df
        if show:
            print(f"\n=== {name} ({len(df)} rows)")
            print(df.head(15).to_string(index=False))
    return results


if __name__ == "__main__":
    main()
