#!/usr/bin/env python3
"""Pin official Node 24 LTS archives using upstream's signed SHA-256 checksums."""
import base64
import json
import pathlib
import re
import subprocess
import tempfile
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent
TARGETS = {
    "aarch64-darwin": "darwin-arm64",
    "aarch64-linux": "linux-arm64",
    "x86_64-linux": "linux-x64",
}
# Node's active release keys, from a second source (GitHub) than the
# checksums (nodejs.org): SHASUMS256.txt must carry a good signature by one
# of them. https://github.com/nodejs/release-keys
RELEASE_KEYS = "https://raw.githubusercontent.com/nodejs/release-keys/HEAD/gpg-only-active-keys/pubring.kbx"


def fetch(url):
    with urllib.request.urlopen(url, timeout=60) as response:
        return response.read()


def verified_checksums(version):
    base = f"https://nodejs.org/dist/v{version}/SHASUMS256.txt"
    checksums = fetch(base)
    with tempfile.TemporaryDirectory() as tmp:
        tmp = pathlib.Path(tmp)
        (tmp / "keys.kbx").write_bytes(fetch(RELEASE_KEYS))
        (tmp / "SHASUMS256.txt").write_bytes(checksums)
        (tmp / "SHASUMS256.txt.sig").write_bytes(fetch(base + ".sig"))
        result = subprocess.run(
            ["gpgv", "--keyring", str(tmp / "keys.kbx"),
             str(tmp / "SHASUMS256.txt.sig"), str(tmp / "SHASUMS256.txt")],
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            raise ValueError(f"SHASUMS256.txt for {version} has no good release-key signature:\n{result.stderr}")
    return checksums.decode()


def main():
    releases = json.loads(fetch("https://nodejs.org/dist/index.json"))
    lts = {
        r["version"][1:]: r for r in releases
        if re.fullmatch(r"v24\.\d+\.\d+", r["version"]) and r["lts"]
    }
    version = max(lts, key=lambda v: tuple(map(int, v.split("."))))
    # The npm Node's release ships (the package's default).
    bundled_npm = lts[version]["npm"]
    if not re.fullmatch(r"\d+\.\d+\.\d+", bundled_npm):
        raise ValueError(f"Unexpected bundled npm version {bundled_npm!r}")
    path = ROOT / "hashes.json"
    current_data = json.loads(path.read_text()) if path.exists() else {}
    current = current_data.get("version")
    npm = json.loads(fetch("https://registry.npmjs.org/npm/latest"))
    if not re.fullmatch(r"\d+\.\d+\.\d+", npm["version"]):
        raise ValueError(f"Unexpected npm version {npm['version']!r}")
    engine = npm["engines"]["node"]
    node_version = tuple(map(int, version.split(".")))
    compatible = False
    # Fail closed on unfamiliar range syntax rather than silently packaging an
    # npm release requiring a newer Node major. npm currently uses ^ / >= ORs.
    for clause in engine.split("||"):
        match = re.fullmatch(r"\s*(\^|>=)(\d+)\.(\d+)\.(\d+)\s*", clause)
        if not match:
            raise ValueError(f"Unsupported npm Node engine range: {engine}")
        op, major, minor, patch = match.groups()
        minimum = (int(major), int(minor), int(patch))
        compatible |= node_version >= minimum and (op == ">=" or node_version[0] == minimum[0])
    if not compatible:
        raise ValueError(f"npm {npm['version']} requires Node {engine}, not {version}")
    expected_url = f"https://registry.npmjs.org/npm/-/npm-{npm['version']}.tgz"
    if npm["dist"]["tarball"] != expected_url:
        raise ValueError("Unexpected npm tarball URL")
    npm_pin = {"version": npm["version"], "hash": npm["dist"]["integrity"]}
    if current == version and current_data.get("npm") == npm_pin and current_data.get("bundledNpm") == bundled_npm:
        print(f"nodejs-24-lts: Node {version}, npm {npm['version']} are latest")
        return

    checksums = verified_checksums(version)
    sums = {}
    for line in checksums.splitlines():
        digest, filename = line.split()
        if not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError("Invalid SHA-256 in upstream checksum list")
        sums[filename] = "sha256-" + base64.b64encode(bytes.fromhex(digest)).decode()
    hashes = {
        system: sums[f"node-v{version}-{target}.tar.xz"]
        for system, target in TARGETS.items()
    }
    path.write_text(json.dumps({"version": version, "bundledNpm": bundled_npm, "hashes": hashes, "npm": npm_pin}, indent=2) + "\n")
    print(f"nodejs-24-lts: {current or 'new'} -> Node {version}, npm {npm['version']}")


if __name__ == "__main__":
    main()
