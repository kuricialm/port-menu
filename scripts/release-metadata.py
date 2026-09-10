#!/usr/bin/env python3
"""Validate fork release metadata; derive a monotonically increasing CI version."""
import re
import sys
from pathlib import Path
import xml.etree.ElementTree as ET

REPO = 'https://github.com/kuricialm/port-menu'
NS = {'s': 'http://www.andymatuschak.org/xml-namespaces/sparkle'}


def version_tuple(value):
    if not re.fullmatch(r'\d+\.\d+\.\d+', value):
        raise ValueError('Expected a three-component release version')
    return tuple(map(int, value.split('.')))


def read_item(path):
    root = ET.parse(path).getroot()
    item = root.find('channel/item')
    if item is None:
        raise ValueError('Release feed has no update')
    version = item.findtext('s:shortVersionString', namespaces=NS)
    build = int(item.findtext('s:version', namespaces=NS))
    version_tuple(version)
    if build < 1:
        raise ValueError('Invalid build')
    return item, version, build


def next_version(base_version, base_build, previous=None):
    version_tuple(base_version)
    if previous is None:
        # Advance beyond the local bootstrap build already installed by Bitrig.
        return base_version, base_build + 1
    old_version, old_build = previous
    version = base_version
    if version_tuple(version) <= version_tuple(old_version):
        major, minor, patch = version_tuple(old_version)
        version = f'{major}.{minor}.{patch + 1}'
    return version, max(base_build, old_build + 1)


def validate(path, version, build):
    item, actual_version, actual_build = read_item(path)
    if (actual_version, actual_build) != (version, int(build)):
        raise ValueError('Feed version does not match the built app')
    enclosure = item.find('enclosure')
    expected_url = f'{REPO}/releases/download/v{version}/PortMenu-{version}.dmg'
    if enclosure is None or enclosure.get('url') != expected_url:
        raise ValueError('Feed points outside this fork release')
    if int(enclosure.get('length', '0')) <= 0 or not enclosure.get('{'+NS['s']+'}edSignature'):
        raise ValueError('Missing archive signature or length')


def main():
    if sys.argv[1] == 'validate':
        validate(*sys.argv[2:])
    elif sys.argv[1] == 'next':
        project = Path('Porter.xcodeproj/project.pbxproj').read_text()
        versions = set(re.findall(r'MARKETING_VERSION = ([\d.]+);', project))
        builds = set(re.findall(r'CURRENT_PROJECT_VERSION = (\d+);', project))
        if len(versions) != 1 or len(builds) != 1:
            raise ValueError('All project configurations must share the same version and build')
        previous = None
        if len(sys.argv) == 3:
            _, previous_version, previous_build = read_item(sys.argv[2])
            previous = (previous_version, previous_build)
        version, build = next_version(versions.pop(), int(builds.pop()), previous)
        print(f'version={version}\nbuild={build}')
    else:
        raise ValueError('Unknown release metadata command')


if __name__ == '__main__':
    main()
