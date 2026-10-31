"""Tiny helpers for running the .sql files against SQLite."""
import re
import sqlite3
from pathlib import Path


def run_script(con: sqlite3.Connection, path: Path) -> None:
    con.executescript(Path(path).read_text(encoding="utf-8"))


def named_queries(path: Path) -> list[tuple[str, str]]:
    """Split a .sql file into (name, query) pairs using '-- name: xxx' markers."""
    text = Path(path).read_text(encoding="utf-8")
    parts = re.split(r"^--\s*name:\s*(\S+)\s*$", text, flags=re.M)
    return [(parts[i].strip(), parts[i + 1].strip().rstrip(";")) for i in range(1, len(parts), 2)]
