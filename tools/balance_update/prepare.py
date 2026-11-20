"""Reconstitute the three exact headless rules projects outside a player profile."""
import argparse
import io
import json
import shutil
import subprocess
import tarfile
from pathlib import Path
from run import FILES, HERE, POLICY_SHA, ROOT, RULES, sha

REVISION = "97df64187053f44307d6fb2e8c23e8c593abac82"


def prepare(scratch):
    scratch.mkdir(parents=True,exist_ok=False)
    control = scratch/"control"
    # Archive the exact read set, not the active tree, installs, or user profiles.
    data = subprocess.check_output(["git","archive","--format=tar",REVISION,"--",*FILES],cwd=ROOT)
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        for name in FILES:
            src = archive.getmember(name)
            assert src.isfile()
            path = control/name
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(archive.extractfile(src).read())
    fingerprints = {n:sha(control/n) for n in FILES}
    assert fingerprints["scripts/game.gd"]==RULES["control"]
    assert fingerprints["tests/playthrough.gd"]==POLICY_SHA
    (scratch/"control-fingerprints.json").write_text(json.dumps(fingerprints,indent=2)+"\n")
    for arm in ("trial-a","trial-b"):
        trial=scratch/arm
        shutil.copytree(control,trial)
        subprocess.run(["git","apply","--no-index",str(HERE/(arm+".patch"))],cwd=trial,check=True)
        assert sha(trial/"scripts/game.gd")==RULES[arm]
    (scratch/"experiment").mkdir()


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("scratch",type=Path,help="new empty root (must not already exist)")
    prepare(p.parse_args().scratch.resolve())
