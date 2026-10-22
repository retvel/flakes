# Pi

[Pi](https://pi.dev) coding agent assembled from official npm releases, using
the flake's `nodejs-24-lts` (official Node 24 LTS binary with independently
pinned npm). This does not compile Pi's
TypeScript, Bun executable, or native helpers. Nix still runs local assembly
steps: fetch/extract packages, install dependencies without lifecycle scripts,
and create a launcher. Node/npm come from upstream release archives. Packaging
tools and system libraries must be cached to avoid compiling those dependencies;
check the dry run first. The npm assembly hook uses nixpkgs' cached Node tooling;
the installed Pi launcher and npm use `nodejs-24-lts`.

## Use

```sh
nix run github:retvel/flakes#pi -- --version
nix build github:retvel/flakes#pi
```

Home Manager or nix-darwin, with `retvel` passed as an input:

```nix
home.packages = [ inputs.retvel.packages.${pkgs.stdenv.hostPlatform.system}.pi ];
```

Supported platforms: Apple Silicon macOS, Linux ARM64 and Linux x86_64. Only
native helpers for the host are retained in the output. Darwin is tested
locally; Linux builds and native-helper loading are checked by CI.
The launcher includes fd/ripgrep, plus Linux clipboard tools. It appends Node
and npm to PATH, preserving the user's preferred Node for commands run by Pi.
It pins `PI_PACKAGE_DIR` to this installation so a parent Pi installation cannot
supply a different version's package assets. User configuration and sessions
remain under the normal Pi directories and are not managed by this package.
No telemetry or other user settings are changed by the wrapper.

## Update

```sh
pkgs/pi/update.sh
nix build --dry-run .#pi
nix build .#pi
```

The updater needs Python 3 (standard library only). It discovers the latest
published version from npm, then downloads the installer lockfiles from the
matching upstream `v<version>` Git tag. Missing integrity hashes are filled from
npm release metadata, with tarball URL checks. The resulting lockfile pins all
runtime packages and their integrity hashes. It fails rather than falling back
to source builds when upstream's versioned installer files are unavailable.
`hashes.json` is the release version marker used by this repo's update workflow;
actual dependency hashes live in `install-lock/package-lock.json`.

Update Pi through this flake, not `pi update self`. Node and npm pins are updated
separately by `pkgs/nodejs-24-lts/update.sh`; they no longer wait for nixpkgs to
package the latest patch. Consumers still explicitly update their flake lock.

## Sources

Packaging checked on 2026-10-22 against Pi 1.4.0:

- https://github.com/earendil-works/pi/tree/v1.4.0/packages/coding-agent/install-lock
- https://github.com/earendil-works/pi/blob/v1.4.0/nix/package.nix
- https://www.npmjs.com/package/@earendil-works/pi-coding-agent

The official Nix package builds workspace packages from source. This package
instead consumes published npm artifacts, whose TUI package includes prebuilt
platform helpers. Install checks verify the Pi version, host native helper and
Photon WASM module. Interactive/model and extension behavior needs separate
runtime testing.
