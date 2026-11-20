"""Focused reporter fixtures: no game process or production saves."""
import json
from pathlib import Path
import tempfile
import unittest
import report
import run


def make_capture(directory):
    run.dump(directory/'design.json',run.design())
    for c in run.cases():
        victory=c['policy']=='tactical' and not c['no_bonuses']
        result=dict(mode='victory' if victory else 'defeat',region=3,hull=80 if victory else 0,min_positive_hull=7,path_taken=[[1,'node']],
                    cards_played=1,turns=1,battles=int(victory))
        fight=dict(region=3,area='fixture',node='node',kind='battle',roster=[['visible',10]],
                   entry_signature='equal-visible',turns=2,end_turns=1,won=victory,plays=1,hull_damage=4)
        row=dict(case=c,status='victory' if victory else 'defeat',result=result,fights=[fight],fingerprint='fixture')
        path=directory/'rows'/c['id']/'row.json';path.parent.mkdir(parents=True)
        run.dump(path,row)


class ReportTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='ascension-reporter-')
        self.d=Path(self.temp.name);make_capture(self.d)

    def tearDown(self): self.temp.cleanup()

    def edit(self,case,update):
        path=self.d/'rows'/case['id']/'row.json';row=json.loads(path.read_text());update(row);run.dump(path,row)

    def test_complete_positive_fixture_has_36_wins_and_both_gates(self):
        r=report.summarize(self.d)
        self.assertTrue(r['gate_passed']);self.assertTrue(r['checkpoint_gate_passed'])
        self.assertEqual(r['recorded'],462);self.assertFalse(r['missing_heldout_tactical_wins'])
        self.assertEqual({x['tier'] for x in r['table']},{0,3})
        self.assertTrue(all(x['min_positive_hull']==7 for x in r['table']))
        self.assertTrue(all(x['equal_entry_turn_deltas']==[0] for x in r['comparisons']))
        self.assertEqual(len([x for x in r['table'] if x['cohort']=='holdout' and x['policy']=='tactical']),72)

    def test_missing_intermediate_does_not_invalidate_complete_checkpoints(self):
        c=next(c for c in run.cases() if c['cohort']=='calibration' and c['rank']==1)
        (self.d/'rows'/c['id']/'row.json').unlink()
        r=report.summarize(self.d)
        self.assertFalse(r['gate_passed']);self.assertTrue(r['checkpoint_gate_passed'])
        self.assertEqual(len(r['unresolved']),1)

    def test_four_losses_cannot_masquerade_as_ship_rank_witness(self):
        for c in run.cases():
            if c['cohort']=='holdout' and c['ship']=='palimpsest' and c['rank']==11 and c['policy']=='tactical':
                self.edit(c,lambda r:r.update(status='defeat'))
        r=report.summarize(self.d)
        self.assertFalse(r['gate_passed']);self.assertFalse(r['checkpoint_gate_passed'])
        self.assertIn(dict(ship='palimpsest',rank=11),r['missing_heldout_tactical_wins'])

    def test_error_row_with_victory_result_is_not_counted(self):
        c=next(c for c in run.cases() if c['cohort']=='holdout' and c['rank']==11 and c['policy']=='tactical')
        self.edit(c,lambda r:r.update(status='error'))
        r=report.summarize(self.d)
        self.assertFalse(r['gate_passed']);self.assertEqual(r['counts']['error'],1)
        self.assertIn(dict(id=c['id'],status='error'),r['unresolved'])

    def test_new_paired_aggressive_victory_is_gate_failure(self):
        c=next(c for c in run.cases() if c['cohort']=='holdout' and c['rank']==2 and c['policy']=='aggressive')
        self.edit(c,lambda r:r.update(status='victory'))
        r=report.summarize(self.d)
        self.assertFalse(r['gate_passed']);self.assertIn(c['id'],r['unexplained_new_aggressive_wins'])

    def test_mixed_fingerprints_refused(self):
        self.edit(run.cases()[0],lambda r:r.update(fingerprint='different'))
        with self.assertRaisesRegex(ValueError,'Mixed candidate'): report.summarize(self.d)

    def test_changed_case_identity_refused(self):
        self.edit(run.cases()[0],lambda r:r['case'].update(rank=11))
        with self.assertRaisesRegex(ValueError,'Plan mismatch'): report.summarize(self.d)

    def test_unplanned_row_refused(self):
        path=self.d/'rows'/'rogue'/'row.json';path.parent.mkdir()
        run.dump(path,dict(case=dict(id='rogue')))
        with self.assertRaisesRegex(ValueError,'Unplanned'): report.summarize(self.d)

if __name__=='__main__': unittest.main()
