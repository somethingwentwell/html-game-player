#!/usr/bin/env python3
"""Archive HTML Arcade and optionally upload the verified bundle to TestFlight."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shlex
import subprocess
import tempfile
import time
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = 'com.warren.htmlarcade'
TEAM = 'WV593VF4XZ'


def run_xcode(command, log_path, env, success_marker):
    # Some managed Macs leave completed developer tools waiting during process teardown.
    # Xcode's final success marker plus validation of the produced archive is authoritative.
    with log_path.open('w') as log:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        deadline = time.monotonic() + 1800
        while time.monotonic() < deadline:
            text = log_path.read_text(errors='replace')
            if success_marker in text:
                return
            status = process.poll()
            if status is not None:
                raise RuntimeError('Xcode did not finish successfully. See ' + str(log_path))
            if '** ARCHIVE FAILED **' in text or '** EXPORT FAILED **' in text:
                raise RuntimeError('Xcode failed. See ' + str(log_path))
            time.sleep(1)
        process.terminate()
        raise TimeoutError('Xcode timed out. See ' + str(log_path))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--credentials', type=Path, default=Path.home() / '.html-arcade/asc.env')
    parser.add_argument('--archive-only', action='store_true')
    parser.add_argument('--upload-existing', type=Path, help='Upload an archive already built and tested')
    parser.add_argument('--output', type=Path, default=ROOT / 'artifacts/release')
    args = parser.parse_args()
    env = dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer', ASC_ENV_FILE=str(args.credentials.expanduser()))
    if args.credentials.expanduser().exists():
        for raw in args.credentials.expanduser().read_text().splitlines():
            if '=' in raw and not raw.lstrip().startswith('#'):
                name, value = raw.removeprefix('export ').split('=', 1)
                env[name.strip()] = shlex.split(value)[0]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)

    def api(method, endpoint, data=None):
        with tempfile.TemporaryDirectory(prefix='html-arcade-api-') as temporary:
            command = ['node', str(ROOT / 'scripts/asc-api.mjs'), method, endpoint]
            if data:
                body = Path(temporary) / 'body.json'
                body.write_text(json.dumps(data))
                command.append(str(body))
            return json.loads(subprocess.check_output(command, env=env, text=True))

    apps = api('GET', '/v1/apps?filter%5BbundleId%5D=' + BUNDLE)['data']
    if not args.archive_only and not apps:
        parser.error('Create the HTML Arcade app record at appstoreconnect.apple.com first (bundle ID ' + BUNDLE + ').')
    bundles = api('GET', '/v1/bundleIds?filter%5Bidentifier%5D=' + BUNDLE)['data']
    if not bundles:
        bundles = [api('POST', '/v1/bundleIds', {'data': {'type': 'bundleIds', 'attributes': {
            'name': 'HTML Arcade', 'identifier': BUNDLE, 'platform': 'IOS'}}})['data']]
    bundle_id = bundles[0]['id']
    certificates = api('GET', '/v1/certificates?filter%5BcertificateType%5D=DISTRIBUTION')['data']
    local_identities = subprocess.check_output(['security', 'find-identity', '-v', '-p', 'codesigning'], text=True)
    certificate = next((item for item in certificates if hashlib.sha1(base64.b64decode(item['attributes']['certificateContent'])).hexdigest().upper() in local_identities), None)
    if not certificate:
        parser.error('No App Store distribution certificate matches an available local private key.')
    profiles = api('GET', '/v1/profiles?filter%5BprofileType%5D=IOS_APP_STORE&limit=200&include=bundleId')['data']
    profile = next((item for item in profiles if item.get('relationships', {}).get('bundleId', {}).get('data', {}).get('id') == bundle_id and item['attributes']['profileState'] == 'ACTIVE'), None)
    if not profile:
        profile = api('POST', '/v1/profiles', {'data': {'type': 'profiles', 'attributes': {
            'name': 'HTML Arcade App Store', 'profileType': 'IOS_APP_STORE'}, 'relationships': {
            'bundleId': {'data': {'type': 'bundleIds', 'id': bundle_id}},
            'certificates': {'data': [{'type': 'certificates', 'id': certificate['id']}]}}}})['data']
    profile_uuid = profile['attributes']['uuid']
    profile_dir = Path.home() / 'Library/Developer/Xcode/UserData/Provisioning Profiles'
    profile_dir.mkdir(parents=True, exist_ok=True)
    (profile_dir / (profile_uuid + '.mobileprovision')).write_bytes(base64.b64decode(profile['attributes']['profileContent']))

    archive = args.upload_existing.resolve() if args.upload_existing else output / 'HTMLArcade.xcarchive'
    if not args.upload_existing:
        subprocess.run(['xcodegen', 'generate'], cwd=ROOT, env=env, check=True)
        build = datetime.now(timezone.utc).strftime('%Y%m%d%H%M')
        command = ['xcodebuild', '-project', 'HTMLArcade.xcodeproj', '-scheme', 'HTMLArcade', '-configuration', 'Release',
                   '-destination', 'generic/platform=iOS', '-archivePath', str(archive),
                   'CODE_SIGN_STYLE=Manual', 'CODE_SIGN_IDENTITY=Apple Distribution',
                   'PROVISIONING_PROFILE_SPECIFIER=' + profile_uuid, 'DEVELOPMENT_TEAM=' + TEAM,
                   'CURRENT_PROJECT_VERSION=' + build, 'archive']
        run_xcode(command, output / 'archive.log', env, '** ARCHIVE SUCCEEDED **')
    app = archive / 'Products/Applications/HTMLArcade.app'
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    if info['CFBundleIdentifier'] != BUNDLE:
        raise RuntimeError('Refusing to upload a different bundle ID.')
    manifest = {'bundle_id': BUNDLE, 'version': info['CFBundleShortVersionString'], 'build': info['CFBundleVersion'],
                'archive': str(archive), 'uploaded': False, 'processing_verified': False}
    if not args.archive_only:
        options = {'method': 'app-store-connect', 'destination': 'upload', 'teamID': TEAM,
                   'signingStyle': 'manual', 'signingCertificate': 'Apple Distribution',
                   'provisioningProfiles': {BUNDLE: profile_uuid}, 'uploadSymbols': True}
        options_path = output / 'ExportOptions.plist'
        options_path.write_bytes(plistlib.dumps(options))
        command = ['xcodebuild', '-exportArchive', '-archivePath', str(archive), '-exportOptionsPlist', str(options_path),
                   '-exportPath', str(output / 'export'), '-authenticationKeyPath', env['ASC_KEY_PATH'],
                   '-authenticationKeyID', env['ASC_KEY_ID'], '-authenticationKeyIssuerID', env['ASC_ISSUER_ID']]
        run_xcode(command, output / 'upload.log', env, '** EXPORT SUCCEEDED **')
        manifest['uploaded'] = True
        manifest['app_id'] = apps[0]['id']
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
