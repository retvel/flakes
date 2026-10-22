#!/usr/bin/env python3
"""Pin upstream's installer lock; add missing registry integrity metadata."""
import concurrent.futures
import json
import pathlib
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent


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


def main():
    latest = registry("@earendil-works/pi-coding-agent", "latest")["version"]
    hashes_path = ROOT / "hashes.json"
    current = json.loads(hashes_path.read_text())["version"] if hashes_path.exists() else None
    if latest == current:
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
    hashes_path.write_text(json.dumps({"version": latest}, indent=2) + "\n")
    print(f"pi: {current or 'new'} -> {latest}")


if __name__ == "__main__":
    main()
