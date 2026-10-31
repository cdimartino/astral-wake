#!/usr/bin/env python3
"""Frozen-policy headless experiments, not manual play or human win rates."""
import argparse
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
    args = parser.parse_args()
    if not 1 <= args.families <= 30 or args.jobs < 1:
        parser.error("families must be 1..30 and jobs must be positive")
    args.scratch = args.scratch.resolve()
    args.scratch.mkdir(parents=True, exist_ok=False)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    planned = list(cases(args.families))
    metadata = {"schema_version": 1, "kind": "automated-headless-baseline",
                "revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                "working_tree": subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True),
                "engine": subprocess.check_output([str(args.engine), "--version"], text=True).strip(),
                "sha256": {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                           for name in ("scripts/game.gd", "scripts/seed_engine.gd", "data/catalog.json", "tests/playthrough.gd")},
                "generation_version": 1, "jobs": args.jobs, "timeout_seconds": args.timeout,
                "planned": planned}
    started = time.monotonic()
    counts = {}
    with args.output.open("x") as output:
        output.write(json.dumps({"metadata": metadata}, sort_keys=True) + "\n")
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
                     "wall_seconds": round(time.monotonic() - started, 3)}}) + "\n")


if __name__ == "__main__":
    main()
