from pathlib import Path
import unittest
from native_test_tools import run_c_fixture
ROOT=Path(__file__).resolve().parents[1]
class LoadingPolicyTests(unittest.TestCase):
    def test_startup_parser_rejects_wrong_or_ambiguous_destinations(self):
        output=run_c_fixture(ROOT/'tests/native_loading_policy_test.c')
        self.assertIn('PASS startup IP/host/port',output)
