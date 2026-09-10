#!/usr/bin/env python3
"""GitHub release guards. Credentials are provided by the hosted workflow only."""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

REPO = 'kuricialm/port-menu'
SHA = os.environ.get('GITHUB_SHA', '')


def gh(*args):
    return subprocess.check_output(['gh', *args], text=True)


def api(path, optional=False):
    result = subprocess.run(['gh', 'api', f'repos/{REPO}/{path}'], text=True, capture_output=True)
    if result.returncode:
        if optional and '(HTTP 404)' in result.stderr:
            return None
        raise RuntimeError(f'GitHub request failed: {path}: {result.stderr.strip()}')
    return json.loads(result.stdout)


def compare_source(previous, candidate):
    if previous == candidate:
        return 'skip'
    comparison = api(f'compare/{previous}...{candidate}')
    if comparison['status'] != 'ahead':
        raise ValueError('This source is older than or diverged from the published release. Refusing to ship it.')
    return 'publish'


def check_source():
    latest = api('releases/latest', optional=True)
    if latest is None:
        return 'publish'
    previous = latest['target_commitish']
    if not re.fullmatch(r'[0-9a-f]{40}', previous):
        raise ValueError('Latest release has no immutable source SHA. Verify its source before continuing.')
    return compare_source(previous, SHA)


def publish(version, build):
    if not re.fullmatch(r'\d+\.\d+\.\d+', version) or not build.isdigit():
        raise ValueError('Invalid release version/build')
    # Recheck immediately before publishing, including after a long notarization.
    if check_source() == 'skip':
        print('This source is already published.')
        return
    tag = f'v{version}'
    release = api(f'releases/tags/{tag}', optional=True)
    if release and (not release['draft'] or release['target_commitish'] != SHA):
        raise ValueError('Release/tag collision: only this commit\'s own draft can be resumed.')
    ref = api(f'git/ref/tags/{tag}', optional=True)
    if ref:
        commit = api(f'commits/refs/tags/{tag}')
        if commit['sha'] != SHA:
            raise ValueError('An existing version tag points to different code. Refusing to overwrite it.')
    output = Path(os.environ['OUTPUT_DIR'])
    assets = [output/f'PortMenu-{version}.dmg', output/'appcast.xml', output/'SHA256SUMS']
    if not all(path.is_file() for path in assets):
        raise ValueError('Verified release assets are missing')
    if not release:
        notes = Path(os.environ['RUNNER_TEMP'])/'portmenu-notes.md'
        notes.write_text(f'Port Menu {version}\n\nBuilt from commit {SHA}. '
                         'Signed with Developer ID and notarized.\n')
        gh('release', 'create', tag, '--repo', REPO, '--target', SHA, '--draft',
           '--title', f'Port Menu {version}', '--notes-file', str(notes))
    # A private draft can safely replace partial uploads. Never modify public assets.
    gh('release', 'upload', tag, '--repo', REPO, '--clobber', *map(str, assets))
    gh('release', 'edit', tag, '--repo', REPO, '--draft=false', '--latest')


if __name__ == '__main__':
    if not re.fullmatch(r'[0-9a-f]{40}', SHA):
        raise SystemExit('GITHUB_SHA must identify the immutable workflow source commit')
    if sys.argv[1] == 'check-source':
        print(check_source())
    elif sys.argv[1] == 'publish':
        publish(*sys.argv[2:])
    else:
        raise SystemExit('Unknown release action')
