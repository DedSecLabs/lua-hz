from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
class NativeOwnershipTests(unittest.TestCase):
    def test_reference_ownership_and_server_policy(self):
        with tempfile.TemporaryDirectory() as directory:
            output=Path(directory)/'policy-test'
            subprocess.run(['gcc','-std=c11','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',
                str(ROOT/'tests/native_visual_policy_test.c'),'-o',str(output)],check=True)
            result=subprocess.run([str(output)],capture_output=True,text=True,check=True)
            self.assertIn('PASS native endpoint policy',result.stdout)
