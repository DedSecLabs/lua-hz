import os
from pathlib import Path
import unittest
from native_test_tools import run_c_fixture

@unittest.skipUnless(os.name=='nt','The exact Win32 address/ABI fixture runs on Windows')
class OpenMPLoadingTests(unittest.TestCase):
    def test_splash_bar_gates_and_ownership_without_game_or_artwork(self):
        source=Path(__file__).with_name('native_openmp_loading_test.c')
        self.assertIn('PASS exact hook ownership/version/signatures',run_c_fixture(source,True))

    def test_build7_splash_bar_gates_and_saved_target_ownership(self):
        source=Path(__file__).with_name('native_openmp_loading_build7_test.c')
        self.assertIn('PASS exact hook ownership/version/signatures',run_c_fixture(source,True))
