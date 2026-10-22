# Node.js 24 LTS

Official prebuilt [Node.js](https://nodejs.org) 24 LTS binaries with an
independently pinned npm release (including npx) from the official npm registry.
The bundled npm is replaced during assembly. No source compilation or npm
install/lifecycle scripts: Nix extracts both archives, pins npm/npx JavaScript
shebangs to this runtime, and patches Linux dynamic-library paths.
The signed macOS Node executable is not modified or re-signed.

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

Python 3 standard library only. The updater selects the newest stable Node 24
release marked LTS in the official release index and pins archive hashes from
its HTTPS SHA-256 manifest. It also pins npm's `latest` release and SHA-512
integrity metadata, checking that its Node engine range supports this runtime.
If latest npm becomes incompatible or uses an unfamiliar engine-range syntax,
the updater fails instead of silently selecting an unverified version. Both
Node and npm are checked even when the Node version has not changed.

It does not independently verify the Node manifest's PGP signature or npm's
publisher signatures. Builds verify downloaded archives against pinned hashes.
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
