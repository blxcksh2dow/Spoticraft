"""Keep scan results tied to the exact published artifact, not just its file name."""
import hashlib
import json
import os
from pathlib import Path
import zipfile

jar = Path('download/spoticraft-26.2.jar')
helper_report = json.loads(Path('build/helper-defender.json').read_text(encoding='utf-8-sig'))
jar_report = json.loads(Path('build/jar-defender.json').read_text(encoding='utf-8-sig'))
assert jar_report['sha256'] == hashlib.sha256(jar.read_bytes()).hexdigest()
with zipfile.ZipFile(jar) as archive:
    assert helper_report['sha256'] == hashlib.sha256(archive.read('native/Spoticraft.Bridge.exe')).hexdigest()
for report in [helper_report, jar_report]:
    assert report['result'] == 'no-detection-on-ci-runner'
result = {
    'architecture': 'precompiled-windows-helper-no-runtime-scripts',
    'sourceCommit': os.environ['GITHUB_SHA'],
    'runUrl': 'https://github.com/' + os.environ['GITHUB_REPOSITORY'] + '/actions/runs/' + os.environ['GITHUB_RUN_ID'],
    'checks': ['native-regression-tests', 'junit-tests', 'jar-content-validation', 'native-process-smoke-test'],
    'scans': [helper_report, jar_report],
    'limitations': 'CI scans are not a guarantee of safety or acceptance by Defender/SmartScreen on another PC. No antivirus exclusions are required or recommended. This does not clear the old reported artifact.'
}
Path('download/spoticraft-26.2-verification.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
