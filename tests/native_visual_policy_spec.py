from pathlib import Path
import unittest
from native_test_tools import run_c_fixture

ROOT=Path(__file__).resolve().parents[1]
class NativeOwnershipTests(unittest.TestCase):
    def test_reference_ownership_and_server_policy(self):
        output=run_c_fixture(ROOT/'tests/native_visual_policy_test.c')
        self.assertIn('PASS native endpoint policy',output)
