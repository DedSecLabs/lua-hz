import importlib.util
from pathlib import Path
import unittest


spec=importlib.util.spec_from_file_location(
    'build_native_loading',Path(__file__).resolve().parents[1]/'tools/build_native_loading.py')
builder=importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class LoadingBuildTests(unittest.TestCase):
    def test_common_storage_restores_section_before_initialized_layout(self):
        source='\t.section .rodata\n\t.local _state\n\t.comm _state,4,4\n_layout:\n\t.long 7\n'
        result=builder.pe_assembly(source)
        self.assertEqual(result, '\t.section .rodata\n_layout:\n\t.long 7\n'
                         '.bss\n.balign 4\n_state:\n.zero 4\n')

    def test_elf_metadata_is_removed_and_code_is_preserved(self):
        source='\t.text\n\t.type _entry, @function\n_entry:\n\tret\n\t.size _entry, .-_entry\n\t.section .note.GNU-stack,"",@progbits\n'
        self.assertEqual(builder.pe_assembly(source),'\t.text\n_entry:\n\tret\n')
