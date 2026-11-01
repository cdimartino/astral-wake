"""Real same-HEAD/dirty-module replay rejection, without editing the worktree."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

engine = sys.argv[1]
source = Path.cwd()
scratch = Path(tempfile.mkdtemp(prefix='astral-reward-fingerprint-', dir=os.environ.get('TMPDIR')))
project = scratch / 'project'
project.mkdir()
for folder in ('scripts', 'tools', 'data'):
    shutil.copytree(source / folder, project / folder)
shutil.copyfile(source / 'project.godot', project / 'project.godot')
# Read-only HEAD identity of the actual worktree, not a fabricated revision string.
gitdir = subprocess.check_output(['git', 'rev-parse', '--absolute-git-dir'], text=True).strip()
(project / '.git').write_text('gitdir: ' + gitdir + '\n')
session = scratch / 'session'


def run(root, *args, expected=0):
    result = subprocess.run([engine, '--headless', '--path', str(root), '--script',
                             'tools/manual_replay.gd', '--', f'--session={session}', *args],
                            text=True, capture_output=True, timeout=120)
    assert result.returncode == expected, (result.stdout, result.stderr)
    assert 'SCRIPT ERROR' not in result.stderr, result.stderr
    return [json.loads(line) for line in result.stdout.splitlines() if line.startswith('{')][-1]


run(source, '--start=0093CG', '--ship=cartographer')
trace = json.loads((session / 'trace.json').read_text())
module = 'scripts/reward_distribution.gd'
assert module in trace['environment']['sources']
assert run(project, '--resume=true')['ok']
head = subprocess.check_output(['git', '-C', str(project), 'rev-parse', 'HEAD'], text=True).strip()
assert head == trace['environment']['game_revision']
with (project / module).open('a') as file:
    file.write('\n# Intentional dirty-same-HEAD fingerprint regression.\n')
assert subprocess.check_output(['git', '-C', str(project), 'rev-parse', 'HEAD'], text=True).strip() == head
result = run(project, '--resume=true', expected=1)
assert not result['ok'] and 'fingerprints' in result['error'], result
print('REWARD_FINGERPRINT clean copied source resumes; dirty authoritative module rejected at same HEAD')
