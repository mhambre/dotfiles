#!/usr/bin/env python3
"""
SQLite filesystem benchmark.

Focuses on filesystem-visible SQLite behavior:
  * bulk inserts
  * durable transaction commit latency
  * random updates
  * random point reads
  * sequential scans
  * optional concurrent readers
  * WAL checkpoint latency (when WAL is enabled)
  * integrity verification

Uses only the Python standard library.

Examples:
  python3 sqlite_fs_bench.py /mnt/test/sqlite-bench.db --size-mib 1024
  python3 sqlite_fs_bench.py /mnt/test/sqlite-bench.db --journal-mode WAL --sync FULL
  python3 sqlite_fs_bench.py /mnt/test/sqlite-bench.db --journal-mode DELETE --batch-size 1
"""

from __future__ import annotations

import argparse
import json
import math
import os
import platform
import random
import sqlite3
import statistics
import subprocess
import threading
import time
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Callable, Iterable


def percentile(values: list[float], p: float) -> float:
    if not values:
        return float("nan")
    xs = sorted(values)
    if len(xs) == 1:
        return xs[0]
    pos = (len(xs) - 1) * p
    lo = math.floor(pos)
    hi = math.ceil(pos)
    if lo == hi:
        return xs[lo]
    frac = pos - lo
    return xs[lo] * (1.0 - frac) + xs[hi] * frac


def latency_summary_ms(values_s: list[float]) -> dict[str, float]:
    vals = [v * 1000.0 for v in values_s]
    if not vals:
        return {}
    return {
        "min_ms": min(vals),
        "mean_ms": statistics.fmean(vals),
        "p50_ms": percentile(vals, 0.50),
        "p95_ms": percentile(vals, 0.95),
        "p99_ms": percentile(vals, 0.99),
        "max_ms": max(vals),
    }


def human_rate(n: float) -> str:
    if n >= 1_000_000:
        return f"{n / 1_000_000:.2f} Mops/s"
    if n >= 1_000:
        return f"{n / 1_000:.2f} Kops/s"
    return f"{n:.2f} ops/s"


def mib_per_s(num_bytes: int, seconds: float) -> float:
    if seconds <= 0:
        return float("inf")
    return num_bytes / (1024 * 1024) / seconds


def get_mount_info(path: Path) -> dict:
    try:
        p = subprocess.run(
            ["findmnt", "-T", str(path), "-J", "-o", "TARGET,SOURCE,FSTYPE,OPTIONS"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
        data = json.loads(p.stdout)
        fs = data.get("filesystems", [])
        return fs[0] if fs else {}
    except Exception:
        return {}


def file_sizes(db_path: Path) -> dict[str, int]:
    out = {}
    for suffix, name in [
        ("", "db"),
        ("-wal", "wal"),
        ("-shm", "shm"),
        ("-journal", "journal"),
    ]:
        p = Path(str(db_path) + suffix)
        if p.exists():
            out[name] = p.stat().st_size
    return out


def make_payload_factory(row_bytes: int, pattern: str, seed: int) -> Callable[[int], bytes]:
    if row_bytes <= 0:
        return lambda _: b""

    if pattern == "zero":
        payload = b"\x00" * row_bytes
        return lambda _: payload

    if pattern == "repeat":
        block = (b"sqlite-fs-bench-" * ((row_bytes // 16) + 1))[:row_bytes]
        return lambda _: block

    # Deterministic pseudo-random payloads. Generate a unique payload per row so
    # compression/dedupe behavior does not make the test accidentally trivial.
    def payload_for(i: int) -> bytes:
        r = random.Random(seed ^ (i * 0x9E3779B185EBCA87))
        return r.randbytes(row_bytes)

    return payload_for


def connect_db(
    db_path: Path,
    journal_mode: str,
    sync: str,
    cache_mib: int,
    busy_timeout_ms: int,
) -> sqlite3.Connection:
    conn = sqlite3.connect(
        str(db_path),
        timeout=max(1.0, busy_timeout_ms / 1000.0),
        isolation_level=None,
        check_same_thread=False,
    )
    conn.execute(f"PRAGMA busy_timeout={busy_timeout_ms}")
    actual_journal = conn.execute(f"PRAGMA journal_mode={journal_mode}").fetchone()[0]
    if actual_journal.lower() != journal_mode.lower():
        raise RuntimeError(
            f"requested journal_mode={journal_mode}, SQLite returned {actual_journal}"
        )
    conn.execute(f"PRAGMA synchronous={sync}")
    conn.execute("PRAGMA temp_store=FILE")
    conn.execute("PRAGMA mmap_size=0")
    conn.execute(f"PRAGMA cache_size={-(cache_mib * 1024)}")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


@dataclass
class Phase:
    name: str
    seconds: float
    operations: int
    logical_bytes: int = 0
    commit_latency_ms: dict | None = None
    extra: dict | None = None

    def print(self) -> None:
        rate = self.operations / self.seconds if self.seconds > 0 else float("inf")
        parts = [f"{self.name:22s}", f"{self.seconds:8.3f}s", f"{human_rate(rate):>13s}"]
        if self.logical_bytes:
            parts.append(f"{mib_per_s(self.logical_bytes, self.seconds):9.2f} MiB/s")
        print("  ".join(parts))
        if self.commit_latency_ms:
            c = self.commit_latency_ms
            print(
                " " * 4
                + "commit latency: "
                + f"p50={c['p50_ms']:.3f} ms  "
                + f"p95={c['p95_ms']:.3f} ms  "
                + f"p99={c['p99_ms']:.3f} ms  "
                + f"max={c['max_ms']:.3f} ms"
            )
        if self.extra:
            for k, v in self.extra.items():
                print(f"    {k}: {v}")


def batched_ids(start: int, end: int, batch_size: int) -> Iterable[range]:
    i = start
    while i < end:
        j = min(end, i + batch_size)
        yield range(i, j)
        i = j


def phase_insert(
    conn: sqlite3.Connection,
    rows: int,
    row_bytes: int,
    batch_size: int,
    payload_for: Callable[[int], bytes],
) -> Phase:
    commits: list[float] = []
    t0 = time.perf_counter()

    for ids in batched_ids(1, rows + 1, batch_size):
        conn.execute("BEGIN IMMEDIATE")
        conn.executemany(
            "INSERT INTO bench(id, payload) VALUES(?, ?)",
            ((i, payload_for(i)) for i in ids),
        )
        c0 = time.perf_counter()
        conn.execute("COMMIT")
        commits.append(time.perf_counter() - c0)

    elapsed = time.perf_counter() - t0
    return Phase(
        name="bulk insert",
        seconds=elapsed,
        operations=rows,
        logical_bytes=rows * row_bytes,
        commit_latency_ms=latency_summary_ms(commits),
    )


def phase_updates(
    conn: sqlite3.Connection,
    rows: int,
    row_bytes: int,
    updates: int,
    batch_size: int,
    payload_for: Callable[[int], bytes],
    seed: int,
) -> Phase:
    rng = random.Random(seed + 1)
    commits: list[float] = []
    done = 0
    t0 = time.perf_counter()

    while done < updates:
        n = min(batch_size, updates - done)
        conn.execute("BEGIN IMMEDIATE")
        params = []
        for j in range(n):
            row_id = rng.randint(1, rows)
            # Use a different payload namespace from inserts.
            params.append((payload_for(rows + done + j + 1), row_id))
        conn.executemany("UPDATE bench SET payload=? WHERE id=?", params)
        c0 = time.perf_counter()
        conn.execute("COMMIT")
        commits.append(time.perf_counter() - c0)
        done += n

    elapsed = time.perf_counter() - t0
    return Phase(
        name="random update",
        seconds=elapsed,
        operations=updates,
        logical_bytes=updates * row_bytes,
        commit_latency_ms=latency_summary_ms(commits),
    )


def phase_point_reads(
    conn: sqlite3.Connection,
    rows: int,
    reads: int,
    row_bytes: int,
    seed: int,
) -> Phase:
    rng = random.Random(seed + 2)
    cur = conn.cursor()
    found_bytes = 0
    latencies: list[float] = []

    t0 = time.perf_counter()
    for _ in range(reads):
        row_id = rng.randint(1, rows)
        q0 = time.perf_counter()
        row = cur.execute("SELECT payload FROM bench WHERE id=?", (row_id,)).fetchone()
        latencies.append(time.perf_counter() - q0)
        if row is None:
            raise RuntimeError(f"missing row {row_id}")
        found_bytes += len(row[0])
    elapsed = time.perf_counter() - t0

    return Phase(
        name="random point read",
        seconds=elapsed,
        operations=reads,
        logical_bytes=found_bytes,
        extra={"read_latency": latency_summary_ms(latencies)},
    )


def phase_scan(conn: sqlite3.Connection) -> Phase:
    rows = 0
    num_bytes = 0
    t0 = time.perf_counter()
    for (payload,) in conn.execute("SELECT payload FROM bench ORDER BY id"):
        rows += 1
        num_bytes += len(payload)
    elapsed = time.perf_counter() - t0
    return Phase(
        name="sequential scan",
        seconds=elapsed,
        operations=rows,
        logical_bytes=num_bytes,
    )


def phase_concurrent_reads(
    db_path: Path,
    journal_mode: str,
    sync: str,
    cache_mib: int,
    busy_timeout_ms: int,
    rows: int,
    threads: int,
    duration: float,
    seed: int,
) -> Phase | None:
    if threads <= 0 or duration <= 0:
        return None

    barrier = threading.Barrier(threads + 1)
    stop = threading.Event()
    counts = [0] * threads
    errors: list[str] = []
    error_lock = threading.Lock()

    def worker(idx: int) -> None:
        rng = random.Random(seed + 1000 + idx)
        try:
            conn = connect_db(
                db_path, journal_mode, sync, cache_mib, busy_timeout_ms
            )
            cur = conn.cursor()
            barrier.wait()
            local = 0
            while not stop.is_set():
                row_id = rng.randint(1, rows)
                row = cur.execute(
                    "SELECT length(payload) FROM bench WHERE id=?", (row_id,)
                ).fetchone()
                if row is None:
                    raise RuntimeError(f"missing row {row_id}")
                local += 1
            counts[idx] = local
            conn.close()
        except Exception as e:
            with error_lock:
                errors.append(f"thread {idx}: {e}")
            try:
                barrier.abort()
            except Exception:
                pass

    workers = [
        threading.Thread(target=worker, args=(i,), daemon=True) for i in range(threads)
    ]
    for t in workers:
        t.start()

    try:
        barrier.wait()
    except threading.BrokenBarrierError:
        pass

    t0 = time.perf_counter()
    if not errors:
        time.sleep(duration)
    stop.set()
    for t in workers:
        t.join()
    elapsed = time.perf_counter() - t0

    if errors:
        raise RuntimeError("; ".join(errors))

    total = sum(counts)
    return Phase(
        name=f"{threads} reader concurrency",
        seconds=elapsed,
        operations=total,
        extra={"per_thread_ops": counts},
    )


def phase_wal_checkpoint(conn: sqlite3.Connection) -> Phase:
    t0 = time.perf_counter()
    result = conn.execute("PRAGMA wal_checkpoint(TRUNCATE)").fetchone()
    elapsed = time.perf_counter() - t0
    return Phase(
        name="WAL checkpoint",
        seconds=elapsed,
        operations=1,
        extra={"checkpoint_result": result},
    )


def cleanup_db(db_path: Path) -> None:
    for suffix in ("", "-wal", "-shm", "-journal"):
        p = Path(str(db_path) + suffix)
        try:
            p.unlink()
        except FileNotFoundError:
            pass


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Benchmark SQLite behavior on a filesystem/mount."
    )
    ap.add_argument("db", type=Path, help="Database path on the filesystem under test")
    ap.add_argument(
        "--size-mib",
        type=int,
        default=512,
        help="Approximate logical payload inserted (default: 512 MiB)",
    )
    ap.add_argument(
        "--row-bytes",
        type=int,
        default=4096,
        help="Payload bytes per row (default: 4096)",
    )
    ap.add_argument(
        "--batch-size",
        type=int,
        default=100,
        help="Rows/updates per transaction (default: 100; use 1 for fsync-heavy testing)",
    )
    ap.add_argument(
        "--updates",
        type=int,
        default=10_000,
        help="Random row updates (default: 10000)",
    )
    ap.add_argument(
        "--reads",
        type=int,
        default=50_000,
        help="Random point reads (default: 50000)",
    )
    ap.add_argument(
        "--reader-threads",
        type=int,
        default=0,
        help="Concurrent random reader threads (default: 0)",
    )
    ap.add_argument(
        "--reader-seconds",
        type=float,
        default=5.0,
        help="Duration for concurrent-reader test (default: 5)",
    )
    ap.add_argument(
        "--journal-mode",
        choices=["DELETE", "TRUNCATE", "PERSIST", "WAL"],
        default="DELETE",
        help="SQLite journal mode (default: DELETE)",
    )
    ap.add_argument(
        "--sync",
        choices=["OFF", "NORMAL", "FULL", "EXTRA"],
        default="FULL",
        help="SQLite synchronous setting (default: FULL)",
    )
    ap.add_argument(
        "--sqlite-cache-mib",
        type=int,
        default=8,
        help="SQLite page cache size per connection (default: 8 MiB)",
    )
    ap.add_argument(
        "--busy-timeout-ms",
        type=int,
        default=30_000,
        help="SQLite lock wait timeout (default: 30000)",
    )
    ap.add_argument(
        "--payload-pattern",
        choices=["random", "zero", "repeat"],
        default="random",
        help="Payload contents (default: random)",
    )
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument(
        "--keep",
        action="store_true",
        help="Keep the database after the benchmark",
    )
    ap.add_argument(
        "--json-out",
        type=Path,
        help="Also write full results as JSON",
    )
    ap.add_argument(
        "--skip-integrity-check",
        action="store_true",
        help="Skip PRAGMA integrity_check",
    )
    args = ap.parse_args()

    if args.size_mib <= 0 or args.row_bytes <= 0:
        ap.error("--size-mib and --row-bytes must be > 0")
    if args.batch_size <= 0:
        ap.error("--batch-size must be > 0")
    if args.updates < 0 or args.reads < 0:
        ap.error("--updates and --reads must be >= 0")

    db_path = args.db.expanduser().resolve()
    db_path.parent.mkdir(parents=True, exist_ok=True)
    cleanup_db(db_path)

    target_bytes = args.size_mib * 1024 * 1024
    rows = max(1, math.ceil(target_bytes / args.row_bytes))
    payload_for = make_payload_factory(args.row_bytes, args.payload_pattern, args.seed)

    meta = {
        "db": str(db_path),
        "python": platform.python_version(),
        "sqlite": sqlite3.sqlite_version,
        "platform": platform.platform(),
        "mount": get_mount_info(db_path.parent),
        "config": {
            "logical_size_mib": args.size_mib,
            "row_bytes": args.row_bytes,
            "rows": rows,
            "batch_size": args.batch_size,
            "updates": args.updates,
            "reads": args.reads,
            "reader_threads": args.reader_threads,
            "reader_seconds": args.reader_seconds,
            "journal_mode": args.journal_mode,
            "sync": args.sync,
            "sqlite_cache_mib": args.sqlite_cache_mib,
            "payload_pattern": args.payload_pattern,
            "seed": args.seed,
        },
    }

    print("SQLite filesystem benchmark")
    print(f"  database:      {db_path}")
    print(f"  SQLite:        {sqlite3.sqlite_version}")
    print(f"  journal mode:  {args.journal_mode}")
    print(f"  synchronous:   {args.sync}")
    print(f"  rows:          {rows:,}")
    print(f"  row payload:   {args.row_bytes:,} bytes")
    print(f"  batch size:    {args.batch_size}")
    if meta["mount"]:
        m = meta["mount"]
        print(
            f"  filesystem:    {m.get('fstype', '?')} "
            f"({m.get('source', '?')} on {m.get('target', '?')})"
        )
    print()

    conn = connect_db(
        db_path,
        args.journal_mode,
        args.sync,
        args.sqlite_cache_mib,
        args.busy_timeout_ms,
    )
    conn.execute(
        "CREATE TABLE bench (id INTEGER PRIMARY KEY, payload BLOB NOT NULL)"
    )

    phases: list[Phase] = []

    try:
        p = phase_insert(
            conn,
            rows,
            args.row_bytes,
            args.batch_size,
            payload_for,
        )
        phases.append(p)
        p.print()

        if args.updates:
            p = phase_updates(
                conn,
                rows,
                args.row_bytes,
                args.updates,
                args.batch_size,
                payload_for,
                args.seed,
            )
            phases.append(p)
            p.print()

        if args.journal_mode == "WAL":
            p = phase_wal_checkpoint(conn)
            phases.append(p)
            p.print()

        if args.reads:
            p = phase_point_reads(
                conn,
                rows,
                args.reads,
                args.row_bytes,
                args.seed,
            )
            phases.append(p)
            p.print()

        p = phase_scan(conn)
        phases.append(p)
        p.print()

        p = phase_concurrent_reads(
            db_path,
            args.journal_mode,
            args.sync,
            args.sqlite_cache_mib,
            args.busy_timeout_ms,
            rows,
            args.reader_threads,
            args.reader_seconds,
            args.seed,
        )
        if p:
            phases.append(p)
            p.print()

        integrity = None
        if not args.skip_integrity_check:
            t0 = time.perf_counter()
            integrity = conn.execute("PRAGMA integrity_check").fetchone()[0]
            integrity_seconds = time.perf_counter() - t0
            print(f"integrity_check:        {integrity} ({integrity_seconds:.3f}s)")
            if integrity != "ok":
                raise RuntimeError(f"integrity_check failed: {integrity}")

        sizes = file_sizes(db_path)
        print()
        print("On-disk files:")
        for name, size in sizes.items():
            print(f"  {name:8s} {size / (1024 * 1024):10.2f} MiB")

        results = {
            "metadata": meta,
            "phases": [asdict(x) for x in phases],
            "integrity_check": integrity,
            "file_sizes_bytes": sizes,
        }

        if args.json_out:
            args.json_out.parent.mkdir(parents=True, exist_ok=True)
            args.json_out.write_text(json.dumps(results, indent=2) + "\n")
            print(f"\nJSON results: {args.json_out}")

    finally:
        conn.close()
        if not args.keep:
            cleanup_db(db_path)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
