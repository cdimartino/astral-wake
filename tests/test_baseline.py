import importlib.util
import pathlib
import unittest

spec = importlib.util.spec_from_file_location(
    "baseline", pathlib.Path(__file__).resolve().parents[1] / "tools/baseline.py")
baseline = importlib.util.module_from_spec(spec)
spec.loader.exec_module(baseline)


class BaselineTests(unittest.TestCase):
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
