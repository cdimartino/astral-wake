"""Focused counterexamples for encounter matching, attribution and option auditing."""
import copy
from pathlib import Path
import unittest
from analyze import check_options, compare, tempo


def fight(node, turns, won=True, hull=80):
    return dict(region=3,area="reef",node=node,kind="boss",roster=[["witness",70]],turns=turns,
                path=[[2,node]],won=won,entry_signature=str(hull),prior_actions="same")


def row(*fights):
    return dict(seed=777,fights=fights,result={"mode":"victory" if fights[-1]["won"] else "defeat"})


class Evidence(unittest.TestCase):
    def test_matched_tempo_does_not_admit_same_node_with_different_roster(self):
        a=fight("A",12); b=fight("B",12); changed=copy.deepcopy(b); changed.update(roster=[["egg",9]],turns=2)
        out=tempo([(row(a,b),row(fight("A",9),changed,fight("C",2)))],False)
        self.assertEqual(out["all_fights"]["med"],[12,2]); self.assertEqual(out["matched"]["n"],[1,1])
        self.assertEqual(out["matched"]["pct"],-25.0)
    def test_clearing_original_losing_node_is_not_necessarily_rescue(self):
        loss=row(fight("A",9,False))
        trial=row(fight("A",5,True,24))
        self.assertEqual(compare(loss,trial)["loss_test"],"original node cleared with different history")
        self.assertEqual(compare(loss,row(fight("B",5)))["loss_test"],"original loss not revisited")
        self.assertEqual(compare(loss,row(fight("A",7)))["loss_test"],"same prefix+entry rescued")
    def test_legacy_starter_only_must_be_tactical_and_disable_bonuses(self):
        c=dict(cohort="legacy",seed=777,ship="palimpsest",policy="starter_only",arm="control",tier=0)
        e=Path("$SCRATCH/experiment/official")
        cmd=["$GODOT","--headless","--path","$SCRATCH/control","--script",str(e/"observer.gd"),"--",
             "--allow-defeat","--seed=777","--character=palimpsest","--policy=tactical","--unlocks=0",
             "--hp-scale=1","--content-pool=1",f"--save-dir={e/'r/save'}","--no-bonuses"]
        check_options(cmd,e,e/"r",c)
        for corrupted in (cmd[:-1],cmd[:9]+["--policy=balanced"]+cmd[10:],cmd+["--unlocks=3"]):
            with self.assertRaises(AssertionError): check_options(corrupted,e,e/"r",c)


if __name__=="__main__":
    unittest.main()
