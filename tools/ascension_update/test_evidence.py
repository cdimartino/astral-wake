import json
from pathlib import Path
import tempfile
import unittest
import audit
import finalize
import run
from test_report import make_capture


class EvidenceTests(unittest.TestCase):
    def test_all36_witnesses_are_existing_exact_rows(self):
        with tempfile.TemporaryDirectory(prefix='ascension-witness-') as tmp:
            d=Path(tmp);make_capture(d)
            proof=finalize.witnesses(d)
            self.assertEqual(len(proof['witnesses']),36);self.assertFalse(proof['missing'])
            for w in proof['witnesses']:
                self.assertEqual(run.sha(d/w['row_path']),w['row_sha256'])
                self.assertEqual(w['row']['case']['rank'],w['rank'])
                self.assertEqual(w['row']['case']['ship'],w['ship'])

    def test_archive_excludes_saves_and_is_byte_reproducible(self):
        with tempfile.TemporaryDirectory(prefix='ascension-archive-') as tmp:
            d=Path(tmp);src=d/'source';(src/'row/save').mkdir(parents=True)
            (src/'row/save/save.json').write_text('private fixture')
            (src/'row/command.json').write_text('{}')
            (src/'row/stdout.log').write_text('fixture')
            a=finalize.archive(d/'a.tar.gz',[('candidate',src)])
            b=finalize.archive(d/'b.tar.gz',[('candidate',src)])
            self.assertEqual(a['sha256'],b['sha256']);self.assertEqual(a['files'],2)

    def test_independent_audit_reads_raw_logs_and_rejects_tamper(self):
        with tempfile.TemporaryDirectory(prefix='ascension-audit-') as tmp:
            d=Path(tmp);make_capture(d)
            engine=d/'engine';engine.write_text('fixture engine')
            manifest=dict(files={'design.json':run.sha(d/'design.json')},engine_path=str(engine),engine_sha256=run.sha(engine))
            run.dump(d/'manifest.json',manifest);fingerprint=run.sha(d/'manifest.json')
            for c in run.cases():
                folder=d/'rows'/c['id'];row=json.loads((folder/'row.json').read_text());r=row['result']
                identity=dict(ascension_rank=c['rank'],modifier_revision=1,rules_revision=1,pool_tier=c['tier'],policy=c['policy'],no_bonuses=c['no_bonuses'])
                r.update(identity,seed=c['code'],character=c['ship'],profile_unlocks=c['tier'],seeded=True,rng_version=1,content_pool_revision=1,reward_generation=1,
                         save_directory=str(folder/'save'),quality=dict(forecast_checks=1,forecast_mismatches=0))
                row.update(fingerprint=fingerprint,returncode=0,quality_errors=[])
                run.dump(folder/'row.json',row)
                lines=['IDENTITY '+json.dumps(identity),'FIGHT '+json.dumps(row['fights'][0]),'ACTION '+json.dumps(dict(selection={})),
                       'ACTION '+json.dumps(dict(selection=dict(end_turn=True))),'PLAYTHROUGH '+json.dumps(r)]
                (folder/'stdout.log').write_text('\n'.join(lines));(folder/'stderr.log').write_text('')
                argv=['--code='+c['code'],'--character='+c['ship'],'--policy='+c['policy'],'--unlocks='+str(c['tier']),'--content-pool=1','--hp-scale=1','--save-dir='+str(folder/'save')]
                if c['no_bonuses']:argv.append('--no-bonuses')
                run.dump(folder/'command.json',dict(argv=argv,env=dict(ASCENSION_RANK=str(c['rank']),ASTRAL_SAVE_DIR=str(folder/'save'))))
            good=audit.audit(d);self.assertTrue(good['passed'],good['errors'])
            folder=d/'rows'/run.cases()[0]['id']
            (folder/'stdout.log').write_text((folder/'stdout.log').read_text().replace('"hull": 80','"hull": 79'))
            bad=audit.audit(d);self.assertFalse(bad['passed']);self.assertTrue(any('raw terminal equality' in e for e in bad['errors']))

if __name__=='__main__':unittest.main()
