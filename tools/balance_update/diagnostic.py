"""Build named diagnostic policies from the frozen immediate scorer."""
import argparse
import textwrap
from run import HERE, POLICY_SHA, sha


def build(scratch):
    parent = scratch/"control/tests/playthrough.gd"
    assert sha(parent)==POLICY_SHA
    src = parent.read_text()
    body = src.split("\t\t\t\tvar score=float(forecast.damage)",1)[1].split('\t\t\t\tif expansion_policy() and definition.has("engine"):',1)[0]
    body = textwrap.dedent("\t\t\t\tvar score=float(forecast.damage)"+body)
    body = body.replace("if forecast.damage>=foe.hp:", "if primary>=foe.hp:").replace("game.run.hull","s.hull").replace("game._incoming_damage(game.run)-int(battle.ward)","danger")
    func = "func point_score(s,forecast,definition,foe,battle,danger,primary) -> float:\n"+textwrap.indent(body,"\t")+"\treturn score\n"
    obs = (HERE/"observer.gd").read_text().replace("var best = super.plan_combat_action()","var best = diagnostic_plan()")
    return obs+"\n"+(HERE/"diagnostic.inc").read_text()+"\n"+func


if __name__=="__main__":
    from pathlib import Path
    import json
    from run import cases
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('scratch',type=Path)
    a=p.parse_args()
    e=a.scratch/"experiment"
    (e/"diagnostic.gd").write_text(build(a.scratch))
    for diag in ("splashfix","visible2"):
        # Six original legacy families, plus the first fresh and full holdouts;
        # use tactical (affected ships' main capable policy).
        rows=[dict(c,diagnostic=diag) for c in cases() if c["policy"]=="tactical"
              and (c["cohort"]=="legacy" or c["family"] in (40,60))]
        (e/(diag+"-cases.json")).write_text(json.dumps(rows,indent=2))
