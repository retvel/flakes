# Pi

[Pi](https://pi.dev) coding agent assembled from official npm releases, using
the flake's `nodejs-24-lts` (official Node 24 LTS binary with the npm it
ships). This does not compile Pi's
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
It also defaults `PI_SKIP_VERSION_CHECK=1` (no `pi.dev` latest-version
request: updates come through this flake; set it yourself to override) and
`PI_TELEMETRY=0` (no install or update telemetry, no provider attribution
headers) unless you set `PI_TELEMETRY` or `enableInstallTelemetry` in Pi's
`settings.json` (global or the project's), which then decides.

## Security overrides

`overrides.json` raises dependencies above upstream's lock when they have
published advisories, as npm `overrides` on top of upstream's own. Each entry
names its version, the advisories and why it stays compatible with Pi:

- `undici` 8.10.2 → 8.12.3 (eight advisories, among them TLS validation
  bypass and cache poisoning): same major; Pi's HTTP dispatcher uses
  `Client`, `Pool`, `EnvHttpProxyAgent`, `install` and `setGlobalDispatcher`.
- `minimatch` 10.2.6 → 11.0.3 (ReDoS-style amplification): a major bump
  (`allowMajor`). 11.0 removes `makeRe()`, `AST`, `matchOne()` and `debug`;
  Pi only calls `minimatch(path, pattern, options)`.

`update.py` applies them to every new upstream lock: it drops an override
once upstream locks that version or newer, refuses one that crosses a major
version without `allowMajor`, re-resolves the lock with npm and checks that
each override is what got locked. The build's install check tests that the
installed versions match and that the APIs Pi uses are still there.

The launcher runs `dist/cli.js`, not the npm bin's `dist/bundle/cli.js`: the
bundle carries its own copies of its dependencies, so the overrides would not
reach it. Upstream supports both ("unbundled" in its `config.js`), and they
run the same setup; starting takes about 0.3 s longer.

To add one: run `npm audit --package-lock-only` in `install-lock/`, check the
fixed version against what Pi uses, add it to `overrides.json` and run
`update.sh`.

## Update

```sh
pkgs/pi/update.sh
nix build --dry-run .#pi
nix build .#pi
```

The updater needs Python 3 (standard library only) and Nix, which provides
npm from `nodejs-24-lts` to re-resolve the lock. It discovers the latest
published version from npm, then downloads the installer lockfiles from the
matching upstream `v<version>` Git tag. Missing integrity hashes are filled from
npm release metadata, with tarball URL checks. The resulting lockfile pins all
runtime packages and their integrity hashes. It fails rather than falling back
to source builds when upstream's versioned installer files are unavailable.
`hashes.json` holds the release version and the overrides applied, the marker
this repo's update workflow uses; actual dependency hashes live in
`install-lock/package-lock.json`.

Update Pi through this flake, not `pi update self`. Node (and its npm) is updated
separately by `pkgs/nodejs-24-lts/update.sh`; it no longer waits for nixpkgs to
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
