#!/usr/bin/env python3
"""Pin upstream's installer lock, apply overrides.json, fill in integrity.

overrides.json lists dependencies to raise above what upstream locks (security
fixes), as npm `overrides`. Each one is checked against upstream's lock: it is
dropped once upstream locks that version or newer, and it may not cross a
major version unless it says `allowMajor` (after checking Pi's use of it).
Needs npm, to re-resolve the lock with the overrides.
"""
import concurrent.futures
import json
import pathlib
import re
import shutil
import subprocess
import tempfile
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent
OVERRIDES = ROOT / "overrides.json"


def fetch(url):
    with urllib.request.urlopen(url, timeout=60) as response:
        return json.load(response)


def registry(name, version):
    return fetch(
        "https://registry.npmjs.org/"
        + urllib.parse.quote(name, safe="@/")
        + "/"
        + urllib.parse.quote(version, safe="")
    )


def semver(version):
    match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)", version)
    if not match:
        raise ValueError(f"Unexpected version {version!r}")
    return tuple(map(int, match.groups()))


def locked_versions(lock, name):
    """Every version of `name` in the lock, by install path."""
    return {
        path: entry["version"]
        for path, entry in lock["packages"].items()
        if path == f"node_modules/{name}" or path.endswith(f"/node_modules/{name}")
    }


def needed_overrides(lock, wanted):
    """The entries of overrides.json still raising a version upstream locks."""
    kept = {}
    for name, override in wanted.items():
        target = semver(override["version"])
        locked = locked_versions(lock, name)
        if not locked:
            print(f"pi: dropping the {name} override: no longer a dependency")
            continue
        if all(semver(v) >= target for v in locked.values()):
            print(f"pi: dropping the {name} override: upstream locks {', '.join(sorted(set(locked.values())))}")
            continue
        for path, version in locked.items():
            if semver(version)[0] != target[0] and not override.get("allowMajor"):
                raise ValueError(
                    f"{name} override {override['version']} crosses the major version of {path} {version}; "
                    "check Pi's use of it, then set allowMajor"
                )
        kept[name] = override
    return kept


def relock(package, lock, overrides):
    """Re-resolve upstream's lock with `overrides` added to its own."""
    package = dict(package)
    package["overrides"] = {
        **package.get("overrides", {}),
        **{name: o["version"] for name, o in overrides.items()},
    }
    if not overrides:
        return package, lock
    with tempfile.TemporaryDirectory() as tmp:
        tmp = pathlib.Path(tmp)
        (tmp / "package.json").write_text(json.dumps(package, indent=2) + "\n")
        (tmp / "package-lock.json").write_text(json.dumps(lock, indent=2) + "\n")
        subprocess.run(
            [shutil.which("npm") or "npm", "install", "--package-lock-only", "--ignore-scripts",
             "--no-audit", "--no-fund", "--registry=https://registry.npmjs.org/"],
            cwd=tmp, check=True,
        )
        lock = json.loads((tmp / "package-lock.json").read_text())
    for name, override in overrides.items():
        versions = set(locked_versions(lock, name).values())
        if versions != {override["version"]}:
            raise ValueError(f"{name} override did not apply: locked {sorted(versions)}")
    return package, lock


def main():
    latest = registry("@earendil-works/pi-coding-agent", "latest")["version"]
    if not re.fullmatch(r"\d+\.\d+\.\d+", latest):
        raise ValueError(f"Unexpected Pi version {latest!r}")
    hashes_path = ROOT / "hashes.json"
    pinned = json.loads(hashes_path.read_text()) if hashes_path.exists() else {}
    current = pinned.get("version")
    wanted = json.loads(OVERRIDES.read_text()) if OVERRIDES.exists() else {}
    if latest == current and pinned.get("overrides", {}) == {n: o["version"] for n, o in wanted.items()}:
        print(f"pi: {current} is latest")
        return

    base = (
        f"https://raw.githubusercontent.com/earendil-works/pi/v{latest}/"
        "packages/coding-agent/install-lock/"
    )
    package = fetch(base + "package.json")
    lock = fetch(base + "package-lock.json")
    if package["dependencies"]["@earendil-works/pi-coding-agent"] != latest:
        raise ValueError("Upstream installer lock does not match the published release")
    if lock["packages"]["node_modules/@earendil-works/pi-coding-agent"]["version"] != latest:
        raise ValueError("Locked Pi version does not match the published release")

    overrides = needed_overrides(lock, wanted)
    package, lock = relock(package, lock, overrides)

    def complete(item):
        path, entry = item
        if "resolved" not in entry:
            if path:
                raise ValueError(f"Unexpected non-registry dependency: {path}")
            return
        if not entry["resolved"].startswith("https://registry.npmjs.org/"):
            raise ValueError(f"Unexpected dependency source: {path}")
        if entry.get("integrity"):
            return
        name = path.rsplit("node_modules/", 1)[-1]
        dist = registry(name, entry["version"])["dist"]
        if dist["tarball"] != entry["resolved"]:
            raise ValueError(f"Registry tarball mismatch: {name}")
        entry["integrity"] = dist["integrity"]

    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        list(pool.map(complete, lock["packages"].items()))

    # Fetch and validate everything before replacing any tracked file. Write
    # the version marker last so a failed update can be rerun.
    lock_dir = ROOT / "install-lock"
    lock_dir.mkdir(exist_ok=True)
    for name, value in [("package.json", package), ("package-lock.json", lock)]:
        (lock_dir / name).write_text(json.dumps(value, indent=2) + "\n")
    if overrides != wanted:
        OVERRIDES.write_text(json.dumps(overrides, indent=2) + "\n")
    hashes_path.write_text(
        json.dumps(
            {"version": latest, "overrides": {n: o["version"] for n, o in overrides.items()}},
            indent=2,
        )
        + "\n"
    )
    print(f"pi: {current or 'new'} -> {latest}, overrides: {', '.join(f'{n}@{o['version']}' for n, o in overrides.items()) or 'none'}")


if __name__ == "__main__":
    main()
