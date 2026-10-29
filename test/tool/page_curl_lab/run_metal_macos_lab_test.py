import importlib.util
import contextlib
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

MODULE = Path(__file__).resolve().parents[3] / 'tool/page_curl_lab/run_metal_macos_lab.py'
SPEC = importlib.util.spec_from_file_location('metal_macos_lab', MODULE)
LAB = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(LAB)


class DedicatedHostTest(unittest.TestCase):
    def test_rejects_repository_and_nested_host(self):
        with tempfile.TemporaryDirectory() as root:
            repository = Path(root)
            for host in [repository, repository / 'macos']:
                with self.assertRaises(ValueError):
                    LAB.validate_host(host, repository)

    def test_smoke_rejects_incompatible_renderer_before_host_access(self):
        for renderer in ['compare', 'metal']:
            arguments = ['lab', '--mode', 'smoke', '--renderer', renderer,
                         '--lab-directory', 'unused', '--epub', 'unused',
                         '--cbz', 'unused', '--pdf', 'unused']
            with patch('sys.argv', arguments), patch.object(LAB, 'validate_host') as validate:
                with contextlib.redirect_stderr(io.StringIO()):
                    with self.assertRaises(SystemExit) as error:
                        LAB.main()
                self.assertEqual(error.exception.code, 2)
                validate.assert_not_called()

    def test_requires_dedicated_package_and_matching_entrypoint(self):
        with tempfile.TemporaryDirectory() as root:
            repository = Path(root).resolve() / 'repository'
            host = Path(root).resolve() / 'host'
            (host / 'lib').mkdir(parents=True)
            pubspec, entrypoint = host / 'pubspec.yaml', host / 'lib/main.dart'
            pubspec.write_text('name: fbooks\n')
            entrypoint.write_text((repository / 'tool/page_curl_lab/main.dart').as_uri())
            with self.assertRaises(ValueError):
                LAB.validate_host(host, repository)
            pubspec.write_text('name: page_curl_metal_lab\n')
            self.assertEqual(LAB.validate_host(host, repository), host)
            entrypoint.write_text('void main() {}')
            with self.assertRaises(ValueError):
                LAB.validate_host(host, repository)


if __name__ == '__main__':
    unittest.main()
