from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
class LoadingPolicyTests(unittest.TestCase):
    def test_startup_parser_rejects_wrong_or_ambiguous_destinations(self):
        with tempfile.TemporaryDirectory() as directory:
            output=Path(directory)/'loading-policy'
            subprocess.run(['gcc','-std=c11','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',
                str(ROOT/'tests/native_loading_policy_test.c'),'-o',str(output)],check=True)
            result=subprocess.run([str(output)],capture_output=True,text=True,check=True)
            self.assertIn('PASS startup IP/host/port',result.stdout)
