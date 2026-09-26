"""Fail the build if the installable JAR still contains the retired scripting bridge."""
import hashlib
import json
from pathlib import Path
import zipfile

artifact = Path('download/spoticraft-26.2.jar')
with zipfile.ZipFile(artifact) as jar:
    assert jar.testzip() is None
    names = jar.namelist()
    forbidden = ('.ps1', '.bat', '.cmd', '.cs', '.vbs', '.js')
    assert not any(n.lower().endswith(forbidden) for n in names), names
    binary = jar.read('native/Spoticraft.Bridge.exe')
    assert binary[:2] == b'MZ', 'Missing Windows PE executable'
    expected = jar.read('native/Spoticraft.Bridge.sha256').decode('ascii').strip()
    assert hashlib.sha256(binary).hexdigest() == expected
    assert binary == Path('build/generated/bridge-resources/native/Spoticraft.Bridge.exe').read_bytes()
    java = jar.read('it/blxckshadow/spoticraft/WindowsSpotify.class').lower()
    for marker in [b'powershell.exe', b'executionpolicy', b'csharpcodeprovider']:
        assert marker not in java, marker
    metadata = json.loads(jar.read('fabric.mod.json'))
    assert metadata['version'] == '26.2'
    assert metadata['depends']['fabricloader'] == '>=0.19.3'
print('Artifact verified: no runtime scripts or C# source; native helper hash matches.')
print('JAR SHA-256:', hashlib.sha256(artifact.read_bytes()).hexdigest())
