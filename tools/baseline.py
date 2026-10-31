#!/usr/bin/env python3
"""Frozen-policy headless experiments, not manual play or human win rates."""
import argparse
import collections
import concurrent.futures
import hashlib
import itertools
import json
import pathlib
import subprocess
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
SHIPS = ("cartographer", "palimpsest", "hollow_choir")
POLICIES = ("balanced", "aggressive", "tactical", "no-bonuses")
SOURCES = ("scripts/game.gd", "scripts/seed_engine.gd", "data/catalog.json", "tests/playthrough.gd")
STATUSES = {"victory", "defeat", "error", "unfinished", "timeout"}


def case_key(row):
    return tuple(row[k] for k in ("family", "seed", "character", "unlocks", "policy"))


def load_capture(path):
    records = [json.loads(line) for line in pathlib.Path(path).read_text().splitlines()]
    if not records or "metadata" not in records[0]:
        raise ValueError("Capture must start with metadata")
    metadata = records[0]["metadata"]
    planned = [case_key(case) for case in metadata["planned"]]
    if len(set(planned)) != len(planned):
        raise ValueError("Duplicate planned case")
    rows, seen, summary = [], set(), None
    for record in records[1:]:
        if summary is not None:
            raise ValueError("Records after final summary")
        if "summary" in record:
            summary = record["summary"]
            continue
        if record.get("status") not in STATUSES:
            raise ValueError("Unknown result status")
        key = case_key(record)
        if key in seen or key not in set(planned):
            raise ValueError("Duplicate or unplanned result")
        seen.add(key)
        rows.append(record)
    if summary is not None and (len(rows) != len(planned) or
            summary.get("counts") != dict(collections.Counter(r["status"] for r in rows))):
        raise ValueError("Summary does not match recorded coverage")
    return metadata, rows, summary


def resume_cases(prior, rows, current, allow_compatible_revision=False):
    for field in ("schema_version", "kind", "engine", "generation_version", "planned", "sha256", "timeout_seconds"):
        if prior.get(field) != current.get(field) or field not in prior:
            raise ValueError("Resume fingerprint mismatch: " + field)
    if set(prior["sha256"]) != set(SOURCES):
        raise ValueError("Resume requires all recorded source fingerprints")
    if prior["revision"] != current["revision"] and not allow_compatible_revision:
        raise ValueError("Revision differs; exact fingerprints require explicit --allow-compatible-revision")
    seen = {case_key(row) for row in rows}
    return [case for case in current["planned"] if case_key(case) not in seen]


def encode(value):
    alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    result = ""
    for _ in range(6):
        value, digit = divmod(value, 36)
        result = alphabet[digit] + result
    return result


def cases(count=30):
    # Published arithmetic sequence, selected before examining outcomes.
    for family, ship, tier, policy in itertools.product(
            range(count), SHIPS, (0, 3), POLICIES):
        value = 424240 + family * 104728 + tier
        yield {"family": family, "seed": encode(value), "character": ship,
               "unlocks": tier, "policy": policy}


def classify(returncode, stdout, stderr):
    lines = [line[12:] for line in stdout.splitlines()
             if line.startswith("PLAYTHROUGH ")]
    try:
        result = json.loads(lines[-1]) if len(lines) == 1 else None
    except json.JSONDecodeError:
        result = None
    if "SCRIPT ERROR" in stderr or "ERROR:" in stderr:
        return "error", result
    if result and returncode == 0 and result.get("mode") in ("victory", "defeat"):
        return result["mode"], result
    if result and returncode == 2:
        return "unfinished", result
    return "error", result


def run_case(case, args):
    key = "{family:02d}-{character}-{unlocks}-{policy}".format(**case)
    directory = args.scratch / key
    directory.mkdir(parents=True, exist_ok=False)
    command = [str(args.engine), "--headless", "--path", str(ROOT),
               "--script", "tests/playthrough.gd", "--", "--allow-defeat",
               "--code=" + case["seed"], "--character=" + case["character"],
               "--unlocks=" + str(case["unlocks"]),
               "--save-dir=" + str(directory / "save")]
    command.append("--no-bonuses" if case["policy"] == "no-bonuses"
                   else "--policy=" + case["policy"])
    started = time.monotonic()
    try:
        completed = subprocess.run(command, capture_output=True, text=True,
                                   timeout=args.timeout)
        stdout, stderr = completed.stdout, completed.stderr
        code = completed.returncode
        status, result = classify(code, stdout, stderr)
    except subprocess.TimeoutExpired as error:
        stdout = (error.stdout or b"").decode(errors="replace")
        stderr = (error.stderr or b"").decode(errors="replace")
        code, status, result = None, "timeout", None
    (directory / "stdout.log").write_text(stdout)
    (directory / "stderr.log").write_text(stderr)
    return {**case, "status": status, "returncode": code, "result": result,
            "process_seconds": round(time.monotonic() - started, 3),
            "log_directory": str(directory)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=pathlib.Path, required=True)
    parser.add_argument("--scratch", type=pathlib.Path, required=True,
                        help="New isolated directory; never use a player save directory")
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--families", type=int, default=30)
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--timeout", type=float, default=180)
    parser.add_argument("--resume-from", type=pathlib.Path,
                        help="Retain every recorded row; run only absent cases")
    parser.add_argument("--allow-compatible-revision", action="store_true",
                        help="Explicitly allow revision differences ONLY when fingerprints match")
    parser.add_argument("--check-resume", action="store_true",
                        help="Validate resume compatibility only; do not create files or run cases")
    args = parser.parse_args()
    if not 1 <= args.families <= 30 or args.jobs < 1 or args.timeout <= 0:
        parser.error("families must be 1..30; jobs and timeout must be positive")
    if args.check_resume and not args.resume_from:
        parser.error("--check-resume requires --resume-from")
    args.scratch = args.scratch.resolve()
    planned = list(cases(args.families))
    metadata = {"schema_version": 1, "kind": "automated-headless-baseline",
                "revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                "working_tree": subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True),
                "engine": subprocess.check_output([str(args.engine), "--version"], text=True).strip(),
                "sha256": {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                           for name in SOURCES},
                "generation_version": 1, "jobs": args.jobs, "timeout_seconds": args.timeout,
                "planned": planned}
    inherited = []
    if args.resume_from:
        try:
            prior, inherited, _ = load_capture(args.resume_from)
            planned = resume_cases(prior, inherited, metadata, args.allow_compatible_revision)
        except (ValueError, KeyError, TypeError) as error:
            parser.error(str(error))
        metadata["resume"] = {
            "capture_sha256": hashlib.sha256(args.resume_from.read_bytes()).hexdigest(),
            "capture": str(args.resume_from.resolve()), "inherited_rows": len(inherited),
            "scheduled_missing": len(planned), "prior_revision": prior["revision"],
            "revision_relationship": "same" if prior["revision"] == metadata["revision"] else "explicit-compatible-fingerprints",
            "prior_metadata": prior}
    if args.output.exists():
        parser.error("Output must be a new file")
    if args.scratch.exists():
        parser.error("Scratch must be a new directory; prior saves are never reused")
    if args.check_resume:
        print(json.dumps({"resume": {k: v for k, v in metadata["resume"].items()
                                    if k != "prior_metadata"}, "check_only": True}, sort_keys=True))
        return
    args.scratch.mkdir(parents=True, exist_ok=False)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    counts = dict(collections.Counter(row["status"] for row in inherited))
    with args.output.open("x") as output:
        output.write(json.dumps({"metadata": metadata}, sort_keys=True) + "\n")
        for row in inherited:
            output.write(json.dumps(row, sort_keys=True) + "\n")
        output.flush()
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as executor:
            futures = [executor.submit(run_case, case, args) for case in planned]
            for future in concurrent.futures.as_completed(futures):
                row = future.result()
                output.write(json.dumps(row, sort_keys=True) + "\n")
                output.flush()
                counts[row["status"]] = counts.get(row["status"], 0) + 1
                print(json.dumps({"completed": sum(counts.values()), "counts": counts}), flush=True)
        output.write(json.dumps({"summary": {"counts": counts,
                     "inherited_rows": len(inherited), "new_rows": len(planned),
                     "wall_seconds": round(time.monotonic() - started, 3)}}) + "\n")


if __name__ == "__main__":
    main()
