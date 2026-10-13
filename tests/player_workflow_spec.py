"""Exercise release publication policy with a disposable mock GitHub CLI."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[1]

@unittest.skipIf(os.name=='nt','GitHub Actions Bash publication-policy fixtures run on Linux')
class PlayerWorkflowTests(unittest.TestCase):
    def run_policy(self, state):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory);player = root / 'dist/player';player.mkdir(parents=True)
            files = {'candidate.zip': b'payload', 'RELEASE_NOTES.md': b'notes',
                     'release-manifest.json': json.dumps({'version':'0.3.0-rc.1','tag':'v0.3.0-rc.1','release_name':'My Car! My F***in’ Car!!'}).encode()}
            for name, content in files.items():(player / name).write_bytes(content)
            (player / 'SHA256SUMS.txt').write_text(''.join(hashlib.sha256(content).hexdigest() + '  ' + name + '\n' for name,content in files.items()))
            mock = root / 'bin';mock.mkdir();log = root / 'calls.txt'
            gh = mock / 'gh'
            gh.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$MOCK_LOG"\ncase "$*" in *"--json isDraft"*) printf "%s\\n" "$MOCK_STATE";; *"--json url"*) echo https://example.invalid/draft;; esac\n')
            gh.chmod(0o755)
            workflow = (ROOT / '.github/workflows/player-release.yml').read_text()
            script = textwrap.dedent(workflow.split('      - name: Prepare draft player release',1)[1].split('        run: |\n',1)[1])
            env = {**os.environ, 'PATH': str(mock)+':'+os.environ['PATH'], 'MOCK_LOG':str(log),
                   'MOCK_STATE':state,'SOURCE_REVISION':'a'*40,'GITHUB_STEP_SUMMARY':str(root/'summary')}
            result = subprocess.run(['bash','-e','-c',script],cwd=root,env=env,capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            return log.read_text()

    def test_published_release_is_never_changed(self):
        calls = self.run_policy('false')
        self.assertNotIn('release upload',calls)
        self.assertNotIn('release edit',calls)
        self.assertNotIn('release create',calls)

    def test_existing_draft_stays_draft_and_is_not_latest(self):
        calls = self.run_policy('true')
        self.assertIn('release upload',calls)
        edit = next(line for line in calls.splitlines() if line.startswith('release edit'))
        self.assertIn('--draft',edit)
        self.assertIn('--prerelease',edit)
        self.assertIn('--latest=false',edit)
        self.assertIn('--target '+('a'*40),edit)
        self.assertIn('--title LuaHZ 0.3.0-rc.1 — My Car! My F***in’ Car!!',edit)

if __name__=='__main__':unittest.main()
