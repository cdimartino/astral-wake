import importlib.util
import collections
import json
import pathlib
import unittest

spec = importlib.util.spec_from_file_location(
    "baseline", pathlib.Path(__file__).resolve().parents[1] / "tools/baseline.py")
baseline = importlib.util.module_from_spec(spec)
spec.loader.exec_module(baseline)


class BaselineTests(unittest.TestCase):
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
