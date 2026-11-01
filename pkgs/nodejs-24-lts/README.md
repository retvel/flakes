# Node.js 24 LTS

Official prebuilt [Node.js](https://nodejs.org) 24 LTS binaries, as
nodejs.org releases them, with the npm (and npx) that release ships. No
source compilation or npm install/lifecycle scripts: Nix extracts the
archive, pins npm/npx JavaScript shebangs to this runtime, and patches Linux
dynamic-library paths. The signed macOS Node executable is not modified or
re-signed.

For npm's latest release instead of the bundled one, override the package:
`nodejs-24-lts.override { pinnedNpm = true; }`. It replaces the bundled npm
with the official npm tarball pinned in `hashes.json` (`npm`), whose Node
engine range the updater checks against this runtime.

```sh
nix run github:retvel/flakes#nodejs-24-lts -- --version
nix build github:retvel/flakes#nodejs-24-lts
```

Supports Apple Silicon macOS, Linux ARM64 and Linux x86_64 (glibc, not musl).
Pi in this flake uses this runtime. Installing Pi does not replace a separately
installed global Node, nor does it change the user's project Node selection.

## Updates

```sh
pkgs/nodejs-24-lts/update.sh
nix build --dry-run .#nodejs-24-lts .#pi
nix build .#nodejs-24-lts .#pi
```

Python 3 standard library only, plus `gpgv`. The updater selects the newest
stable Node 24 release marked LTS in the official release index, records the
npm it ships (`bundledNpm`), and pins archive hashes from its SHA-256 manifest,
which must carry a good signature by a Node release key (the keyring comes
from github.com/nodejs/release-keys, a second source). It also pins npm's
`latest` release and SHA-512 integrity metadata for `pinnedNpm`, checking that
its Node engine range supports this runtime.
If latest npm becomes incompatible or uses an unfamiliar engine-range syntax,
the updater fails instead of silently selecting an unverified version. Both
Node and npm are checked even when the Node version has not changed.

It does not verify npm's publisher signatures. Builds verify downloaded
archives against pinned hashes.
Latest does not imply vulnerability-free; advisories need separate review.
No automatic major-version migration. Downstream flake locks still require an
explicit update to consume a newer runtime.

Linux system libraries and packaging tools come from nixpkgs. Check the dry run
before building: no local compilation requires those dependencies to be cached.
Install checks run Node, npm and npx. Darwin is tested locally; Linux is left to
CI. Upstream prebuilt binaries can have stricter OS minimums than nixpkgs builds.

Sources checked 2026-10-22 for Node 24.22.1 and npm 12.2.1:

- https://nodejs.org/dist/index.json
- https://nodejs.org/dist/v24.22.1/SHASUMS256.txt
- https://nodejs.org/dist/v24.22.1/
- https://registry.npmjs.org/npm/latest
