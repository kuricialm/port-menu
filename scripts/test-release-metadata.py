#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('release_metadata', Path(__file__).with_name('release-metadata.py'))
metadata = importlib.util.module_from_spec(spec)
spec.loader.exec_module(metadata)

class ReleaseMetadataTests(unittest.TestCase):
    def test_first_release_advances_beyond_installed_bootstrap(self):
        self.assertEqual(metadata.next_version('0.8.15', 23), ('0.8.15', 24))

    def test_forgotten_or_older_version_still_advances(self):
        self.assertEqual(metadata.next_version('0.8.15', 23, ('0.8.15', 23)), ('0.8.16', 24))
        self.assertEqual(metadata.next_version('0.8.14', 22, ('0.8.16', 24)), ('0.8.17', 25))

    def test_intentional_new_version_is_preserved(self):
        self.assertEqual(metadata.next_version('0.9.0', 23, ('0.8.16', 24)), ('0.9.0', 25))

    def test_foreign_download_or_mismatched_build_is_rejected(self):
        xml = '''<rss xmlns:s="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item>
        <s:version>23</s:version><s:shortVersionString>0.8.15</s:shortVersionString>
        <enclosure url="https://github.com/kuricialm/port-menu/releases/download/v0.8.15/PortMenu-0.8.15.dmg"
        s:edSignature="signature" length="123"/></item></channel></rss>'''
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp)/'appcast.xml'
            path.write_text(xml)
            metadata.validate(path, '0.8.15', 23)
            with self.assertRaises(ValueError):
                metadata.validate(path, '0.8.15', 24)
            path.write_text(xml.replace('kuricialm', 'wieandteduard'))
            with self.assertRaises(ValueError):
                metadata.validate(path, '0.8.15', 23)

class ReleaseSourceTests(unittest.TestCase):
    def test_identical_old_and_diverged_sources(self):
        from unittest.mock import patch
        spec = importlib.util.spec_from_file_location('release_github', Path(__file__).with_name('release-github.py'))
        release = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(release)
        with patch.object(release, 'api', return_value={'status':'ahead'}):
            self.assertEqual(release.compare_source('a', 'a'), 'skip')
            self.assertEqual(release.compare_source('a', 'b'), 'publish')
        for status in ['behind', 'diverged']:
            with patch.object(release, 'api', return_value={'status':status}):
                with self.assertRaises(ValueError):
                    release.compare_source('a', 'b')

class ReleasePublicationTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('release_github', Path(__file__).with_name('release-github.py'))
        self.release = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.release)
        self.release.SHA = 'a' * 40

    def test_resumes_own_draft_but_does_not_overwrite_public_release(self):
        from unittest.mock import patch
        import os
        with tempfile.TemporaryDirectory() as temp:
            for name in ['PortMenu-0.8.15.dmg', 'appcast.xml', 'SHA256SUMS']:
                (Path(temp)/name).write_text('fixture')
            with patch.dict(os.environ, {'OUTPUT_DIR': temp}), patch.object(self.release, 'check_source', return_value='publish'):
                with patch.object(self.release, 'api', side_effect=[{'draft':True,'target_commitish':self.release.SHA}, None]), patch.object(self.release, 'gh') as gh:
                    self.release.publish('0.8.15', '23')
                    self.assertEqual([c.args[1] for c in gh.call_args_list], ['upload', 'edit'])
                    self.assertIn('--clobber', gh.call_args_list[0].args)
                for release in [{'draft':False,'target_commitish':self.release.SHA},
                                {'draft':True,'target_commitish':'b'*40}]:
                    with patch.object(self.release, 'api', return_value=release), patch.object(self.release, 'gh') as gh:
                        with self.assertRaises(ValueError):
                            self.release.publish('0.8.15', '23')
                        gh.assert_not_called()

    def test_failed_upload_never_publishes_draft(self):
        from unittest.mock import patch
        import os
        with tempfile.TemporaryDirectory() as temp:
            for name in ['PortMenu-0.8.15.dmg', 'appcast.xml', 'SHA256SUMS']:
                (Path(temp)/name).write_text('fixture')
            with patch.dict(os.environ, {'OUTPUT_DIR': temp}), patch.object(self.release, 'check_source', return_value='publish'), patch.object(self.release, 'api', side_effect=[{'draft':True,'target_commitish':self.release.SHA},None]), patch.object(self.release, 'gh', side_effect=RuntimeError('upload failed')) as gh:
                with self.assertRaises(RuntimeError):
                    self.release.publish('0.8.15', '23')
                self.assertEqual(gh.call_count, 1)
                self.assertEqual(gh.call_args.args[1], 'upload')

if __name__ == '__main__':
    unittest.main()
