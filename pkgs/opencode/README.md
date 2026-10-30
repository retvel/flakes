# opencode

[OpenCode](https://opencode.ai) 2 from upstream's prebuilt release, as
published to npm (`@opencode/cli-<platform>`, the package
`opencode.ai/v2/install` installs). Nothing is compiled.

`libexec/opencode` is upstream's single Bun-compiled binary. On macOS it is
untouched (`dontFixup`); on Linux it needs only glibc, so its interpreter is
pointed at Nix's loader (stripping is off, since that would cut off the program
Bun appends). `bin/opencode` is a wrapper that keeps it on Nix:

- `OPENCODE_DISABLE_AUTOUPDATE=1`: no update check, and no automatic install
  of a newer release.
- `opencode upgrade` / `opencode update` are refused: they would install a
  second copy into `~/.opencode/bin`. Update the flake input instead.
- ripgrep from Nix is appended to `PATH`, so OpenCode doesn't download its own
  into `~/.cache/opencode/bin`.

The background server (`opencode service`) runs this same store binary; after
an update, `opencode service restart` moves it to the new one. Shell
completions for bash, fish and zsh come from `opencode --completions`.
Config, logins and sessions stay in `~/.config/opencode` and
`~/.local/share/opencode`; plugins and language servers OpenCode fetches at
runtime go to `~/.cache/opencode`, as upstream does.

Systems: `aarch64-darwin`, `x86_64-linux`, `aarch64-linux`. The x86_64 binary
needs AVX2 (upstream's `-baseline` build is for older CPUs).

## Updates

`update.sh` follows npm's `latest` tag of `@opencode/cli` (the version
`opencode.ai/update/api/latest/cli/npm` reports) and pins each platform
package by the integrity hash the registry publishes, so nothing is
downloaded.
