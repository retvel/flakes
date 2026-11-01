# Install check for a macOS app bundle, without opening it: the executable
# Info.plist names is there, and, given a version, the bundle says it is that
# version. Used by pkgs/*/package.nix: python3 check-app.py APP [VERSION]
import os
import plistlib
import sys

app = sys.argv[1]
version = sys.argv[2] if len(sys.argv) > 2 else ""
with open(os.path.join(app, "Contents", "Info.plist"), "rb") as f:
    info = plistlib.load(f)
exe = os.path.join(app, "Contents", "MacOS", info["CFBundleExecutable"])
if not os.access(exe, os.X_OK):
    sys.exit(f"{app}: {exe} is not an executable")
found = info.get("CFBundleShortVersionString", "")
if version and found != version:
    sys.exit(f"{app}: bundle version {found!r}, expected {version!r}")
print(f"{app}: {info['CFBundleExecutable']} {found}")
