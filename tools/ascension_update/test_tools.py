import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import run
import report
import parity
import holdout_checkpoints

class ToolTests(unittest.TestCase):
    def test_schedule(self):
        rows=run.cases()
        self.assertEqual(len(rows),462)
        self.assertEqual(sum(c['arm']=='primary' for c in rows),432)
        self.assertEqual(sum(c['no_bonuses'] for c in rows),30)
        self.assertEqual(len({c['id'] for c in rows}),462)
        for s in run.seeds():
            self.assertEqual(int(s['code'],36)%4,s['tier'])
        self.assertEqual(run.design(),json.loads((run.HERE/'design.json').read_text()))

    def test_historical_disjoint(self):
        old=json.loads((run.ROOT/'tools/balance_update/design.json').read_text())
        codes={r['seed'] for group in old['modern'].values() for r in group}
        codes|={run.encode(424240+i*104728+t) for i in range(30) for t in (0,3)}
        self.assertFalse(codes & {s['code'] for s in run.seeds()})

    def test_rank_independence(self):
        rows=run.cases()
        for seed in run.seeds():
            matched=[c for c in rows if c['code']==seed['code'] and c['arm']=='primary']
            self.assertEqual(len(matched),72)
            for ship in run.SHIPS:
                for policy in ('tactical','aggressive'):
                    self.assertEqual({c['rank'] for c in matched if c['ship']==ship and c['policy']==policy},set(range(12)))

    def test_adapter_only_edits_contract(self):
        source=(run.ROOT/'tests/playthrough.gd').read_text()
        adapted=run.adapt(source)
        self.assertIn('new_run(seed_value,character_id,ascension_rank)',adapted)
        self.assertIn('game.profile.ascension_unlocks=',adapted)
        # All policy functions below initialization are byte-identical.
        self.assertEqual(source.split('func prepare_routes()',1)[1],adapted.split('func prepare_routes()',1)[1])
        with self.assertRaises(AssertionError): run.adapt('changed')

    def test_freeze_needs_signal(self):
        with self.assertRaises(ValueError): run.freeze(Path('/not-created'),Path('/none'),'')

    def test_dependency_walk(self):
        files=run.dependency_files(run.ROOT)
        self.assertIn('data/catalog.json',files)
        self.assertIn('scripts/save_store.gd',files)
        self.assertIn('scripts/seed_engine.gd',files)

    def test_validate_rejects_empty(self):
        self.assertTrue(run.validate(run.cases()[0],{},[],Path('/fake')))

    def test_report_missing_not_success(self):
        with tempfile.TemporaryDirectory(prefix='ascension-unit-') as tmp:
            d=Path(tmp)
            run.dump(d/'design.json',run.design())
            r=report.summarize(d)
            self.assertFalse(r['gate_passed'])
            self.assertEqual(len(r['unresolved']),462)
            self.assertEqual(len(r['missing_heldout_tactical_wins']),36)

    def test_timeout_persists_row_and_logs(self):
        with tempfile.TemporaryDirectory(prefix='ascension-unit-') as tmp:
            d=Path(tmp)
            run.dump(d/'manifest.json',dict(engine_path='fake-engine'))
            with patch('run.subprocess.run',side_effect=subprocess.TimeoutExpired('fake',1,output=b'partial',stderr=b'timed')):
                r=run.run_case(run.cases()[0],d,'fixture-fingerprint',1)
            self.assertEqual(r['status'],'timeout')
            out=d/'rows'/run.cases()[0]['id']
            self.assertEqual((out/'stdout.log').read_text(),'partial')
            self.assertTrue((out/'row.json').exists())

    def test_parity_strata_and_normalization(self):
        meta, rows=parity.selected(parity.CAPTURE)
        self.assertEqual(len(rows),24)
        self.assertEqual(len({(r['character'],r['unlocks'],r['policy']) for r in rows}),24)
        a={'hull':42,'deck':[1],'wall_seconds':1,'save_directory':'old'}
        b=dict(a,wall_seconds=99,save_directory='new',ascension_rank=0,modifier_revision=1)
        self.assertEqual(parity.normalize(a),parity.normalize(b))
        b['hull']=41
        self.assertNotEqual(parity.normalize(a),parity.normalize(b))

    def test_holdout_subset_does_not_change_predeclaration(self):
        with tempfile.TemporaryDirectory(prefix='ascension-unit-') as tmp:
            d=Path(tmp)
            run.dump(d/'design.json',run.design())
            rows=holdout_checkpoints.planned(d)
            self.assertEqual(len(rows),120)
            self.assertEqual({c['rank'] for c in rows},set(run.CHECKPOINTS))
            self.assertTrue(all(c in run.cases() for c in rows))

    def test_workers_and_sequence_guards(self):
        with self.assertRaises(ValueError): run.run_phase(Path('/none'),run.PHASES[0],5,1,'yes')
        with self.assertRaises(ValueError): run.run_phase(Path('/none'),run.PHASES[0],1,1,'')

if __name__=='__main__': unittest.main()
