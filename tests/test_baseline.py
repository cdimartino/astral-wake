import importlib.util
import collections
import contextlib
import copy
import io
import json
import pathlib
import tempfile
import unittest
from unittest import mock

spec = importlib.util.spec_from_file_location(
    "baseline", pathlib.Path(__file__).resolve().parents[1] / "tools/baseline.py")
baseline = importlib.util.module_from_spec(spec)
spec.loader.exec_module(baseline)


class BaselineTests(unittest.TestCase):
    def test_complete_resumed_capture_and_report(self):
        root = pathlib.Path(__file__).resolve().parents[1]
        path = root / "docs/baselines/issue22-complete-resumed.jsonl"
        prior_path = root / "docs/baselines/issue22-integration-interrupted.jsonl"
        metadata, rows, summary = baseline.load_capture(path)
        prior, inherited, _ = baseline.load_capture(prior_path)
        self.assertEqual(baseline.hashlib.sha256(path.read_bytes()).hexdigest(),
                         "50a1666218ed4c3d564f7c01a287af5efb58f8e30af796dcccdedce9b355bdc8")
        self.assertEqual(len(rows), 720)
        self.assertEqual(metadata["planned"], list(baseline.cases()))
        self.assertEqual(rows[:354], inherited)
        self.assertEqual(path.read_bytes().splitlines()[1:355],
                         prior_path.read_bytes().splitlines()[1:])
        self.assertEqual(metadata["resume"]["prior_metadata"], prior)
        self.assertEqual(metadata["resume"]["capture_sha256"],
                         baseline.hashlib.sha256(prior_path.read_bytes()).hexdigest())
        self.assertEqual(metadata["resume"]["revision_relationship"], "explicit-compatible-fingerprints")
        missing = baseline.resume_cases(prior, inherited, metadata, True)
        self.assertEqual({baseline.case_key(c) for c in missing},
                         {baseline.case_key(r) for r in rows[354:]})
        self.assertEqual(len(missing), 366)
        self.assertEqual(summary["inherited_rows"], 354)
        self.assertEqual(summary["new_rows"], 366)
        self.assertEqual(summary["wall_seconds"], 937.623)
        self.assertEqual(summary["counts"], {"victory": 141, "defeat": 544, "timeout": 35})
        self.assertFalse(any(r["status"] == "timeout" for r in rows[354:]))
        for ship, victories in (("cartographer", 42), ("hollow_choir", 40), ("palimpsest", 16)):
            tactical = [r for r in rows if r["character"] == ship and r["policy"] == "tactical"]
            self.assertEqual(len(tactical), 60)
            self.assertEqual(sum(r["status"] == "victory" for r in tactical), victories)
        for ship in baseline.SHIPS:
            for tier in (0, 3):
                for policy in baseline.POLICIES:
                    group = [r for r in rows if (r["character"], r["unlocks"], r["policy"]) == (ship, tier, policy)]
                    self.assertEqual(len(group), 30)
                    self.assertEqual(len({r["seed"] for r in group}), 30)
        spec = importlib.util.spec_from_file_location("baseline_report", root / "tools/baseline_report.py")
        report = importlib.util.module_from_spec(spec)
        with mock.patch.dict("sys.modules", {"baseline": baseline}):
            spec.loader.exec_module(report)
        text = io.StringIO()
        with contextlib.redirect_stdout(text):
            report.report(path)
        self.assertIn("Recorded 720/720 cases; missing 0.", text.getvalue())
        self.assertNotIn("INTERRUPTED / INCOMPLETE", text.getvalue())
        self.assertIn(text.getvalue(), path.with_suffix(".md").read_text())

    def fixture(self):
        metadata = {"schema_version": 1, "kind": "automated-headless-baseline",
                    "revision": "old", "engine": "engine-1", "generation_version": 1,
                    "planned": list(baseline.cases(1)), "timeout_seconds": 180,
                    "sha256": {name: "abc" for name in baseline.SOURCES}}
        rows = [{**case, "status": status, "result": None, "returncode": None}
                for case, status in zip(metadata["planned"],
                                       ("victory", "defeat", "error", "unfinished", "timeout"))]
        return metadata, rows

    def write_capture(self, path, metadata, rows):
        path.write_text("\n".join(json.dumps(r) for r in [{"metadata": metadata}, *rows]) + "\n")

    def test_resume_skips_every_recorded_status(self):
        metadata, rows = self.fixture()
        pending = baseline.resume_cases(metadata, rows, copy.deepcopy(metadata))
        self.assertEqual(pending, metadata["planned"][5:])
        self.assertEqual([r["status"] for r in rows],
                         ["victory", "defeat", "error", "unfinished", "timeout"])

    def test_resume_rejects_mismatches_even_with_revision_permission(self):
        prior, rows = self.fixture()
        for field in ("planned", "sha256", "engine", "generation_version", "timeout_seconds"):
            current = copy.deepcopy(prior)
            current[field] = [] if field == "planned" else "different"
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, field):
                baseline.resume_cases(prior, rows, current, True)
        current = copy.deepcopy(prior)
        current["revision"] = "new"
        with self.assertRaisesRegex(ValueError, "Revision differs"):
            baseline.resume_cases(prior, rows, current)
        self.assertEqual(len(baseline.resume_cases(prior, rows, current, True)), 19)

    def test_capture_rejects_duplicates_unplanned_and_malformed_rows(self):
        metadata, rows = self.fixture()
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "capture.jsonl"
            for bad in (rows + [rows[0]], [{**rows[0], "family": 999}],
                        [{**rows[0], "status": "cancelled"}]):
                self.write_capture(path, metadata, bad)
                with self.assertRaises(ValueError):
                    baseline.load_capture(path)
            duplicate_plan = copy.deepcopy(metadata)
            duplicate_plan["planned"].append(metadata["planned"][0])
            self.write_capture(path, duplicate_plan, rows)
            with self.assertRaisesRegex(ValueError, "Duplicate planned"):
                baseline.load_capture(path)
            path.write_text('{"metadata":')
            with self.assertRaises(ValueError):
                baseline.load_capture(path)

    def test_resume_main_preserves_rows_and_schedules_only_missing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            prior, rows = self.fixture()
            prior["revision"] = "new"
            prior["sha256"] = {name: baseline.hashlib.sha256((baseline.ROOT / name).read_bytes()).hexdigest()
                               for name in baseline.SOURCES}
            source = root / "source.jsonl"
            self.write_capture(source, prior, rows)
            original = source.read_bytes()
            output, scratch = root / "resumed.jsonl", root / "new-scratch"
            argv = ["baseline", "--engine", "unused", "--resume-from", str(source),
                    "--scratch", str(scratch), "--output", str(output), "--families", "1"]
            def fake_run(case, args):
                return {**case, "status": "defeat", "result": None}
            with mock.patch("sys.argv", argv), mock.patch.object(baseline.subprocess, "check_output", side_effect=["new\n", "", "engine-1\n"]), mock.patch.object(baseline, "run_case", side_effect=fake_run) as run, contextlib.redirect_stdout(io.StringIO()):
                baseline.main()
            self.assertEqual(run.call_count, 19)
            metadata, recorded, summary = baseline.load_capture(output)
            self.assertEqual(recorded[:5], rows)
            self.assertEqual(summary["counts"]["timeout"], 1)
            self.assertEqual(summary["counts"]["error"], 1)
            self.assertEqual(metadata["resume"]["scheduled_missing"], 19)
            self.assertEqual(source.read_bytes(), original)
            sentinel = scratch / "existing-save"
            sentinel.write_text("preserve")
            argv[argv.index(str(output))] = str(root / "second.jsonl")
            with mock.patch("sys.argv", argv), mock.patch.object(baseline.subprocess, "check_output", side_effect=["new\n", "", "engine-1\n"]), mock.patch.object(baseline, "run_case") as run, contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                baseline.main()
            run.assert_not_called()
            self.assertEqual(sentinel.read_text(), "preserve")
            argv[argv.index(str(scratch))] = str(root / "check-only-scratch")
            argv.append("--check-resume")
            with mock.patch("sys.argv", argv), mock.patch.object(baseline.subprocess, "check_output", side_effect=["new\n", "", "engine-1\n"]), mock.patch.object(baseline, "run_case") as run, contextlib.redirect_stdout(io.StringIO()):
                baseline.main()
            run.assert_not_called()
            self.assertFalse((root / "check-only-scratch").exists())
            self.assertFalse((root / "second.jsonl").exists())

    def test_interrupted_integration_capture(self):
        path = pathlib.Path(__file__).resolve().parents[1] / "docs/baselines/issue22-integration-interrupted.jsonl"
        metadata, rows, summary = baseline.load_capture(path)
        self.assertIsNone(summary)
        self.assertEqual(len(metadata["planned"]), 720)
        self.assertEqual(len(rows), 354)
        self.assertEqual(collections.Counter(r["status"] for r in rows),
                         {"victory": 62, "defeat": 257, "timeout": 35})
        self.assertEqual(baseline.hashlib.sha256(path.read_bytes()).hexdigest(),
                         "e2129b83c1fc8a8fe856330e6c50da6f46eb5f546d7edfa153a23d7441bd83a1")

    def test_committed_capture_integrity(self):
        root = pathlib.Path(__file__).resolve().parents[1]
        frozen_hashes = None
        for name, expected in (("representative", {"victory": 3, "defeat": 19, "timeout": 2}),
                               ("full", {"victory": 3, "defeat": 21, "timeout": 3})):
            records = [json.loads(line) for line in
                       (root / f"docs/baselines/issue22-{name}.jsonl").read_text().splitlines()]
            metadata = records[0]["metadata"]
            rows = [r for r in records if "status" in r]
            self.assertEqual(collections.Counter(r["status"] for r in rows), expected)
            planned = {tuple(sorted(c.items())) for c in metadata["planned"]}
            seen = set()
            for row in rows:
                case = tuple(sorted((k, row[k]) for k in ("seed", "family", "character", "unlocks", "policy")))
                self.assertIn(case, planned)
                self.assertNotIn(case, seen)
                seen.add(case)
                if row["result"]:
                    self.assertEqual(row["result"]["seed"], row["seed"])
                    self.assertEqual(row["result"]["pool_tier"], row["unlocks"])
                    self.assertEqual(row["result"]["profile_unlocks"], row["unlocks"])
                    self.assertEqual(row["result"]["rng_version"], 1)
            if frozen_hashes is None:
                frozen_hashes = metadata["sha256"]
            self.assertEqual(metadata["sha256"], frozen_hashes)

    def test_published_matrix(self):
        cases = list(baseline.cases())
        self.assertEqual(len(cases), 720)
        self.assertEqual(len({tuple(case.values()) for case in cases}), 720)
        for ship in baseline.SHIPS:
            for tier in (0, 3):
                for policy in baseline.POLICIES:
                    group = [c for c in cases if (c["character"], c["unlocks"], c["policy"]) == (ship, tier, policy)]
                    self.assertEqual(len({c["seed"] for c in group}), 30)
                    self.assertTrue(all(int(c["seed"], 36) % 4 == tier for c in group))

    def test_errors_are_not_losses(self):
        loss = 'PLAYTHROUGH {"mode":"defeat"}\n'
        self.assertEqual(baseline.classify(0, loss, "")[0], "defeat")
        for code, stdout, stderr in [(1, loss, ""), (0, loss, "SCRIPT ERROR: bad"),
                                     (0, "", ""), (0, "PLAYTHROUGH broken", "")]:
            self.assertEqual(baseline.classify(code, stdout, stderr)[0], "error")
        self.assertEqual(baseline.classify(2, 'PLAYTHROUGH {"mode":"combat"}', "")[0], "unfinished")


if __name__ == "__main__":
    unittest.main()
