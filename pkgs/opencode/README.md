# opencode

[OpenCode](https://opencode.ai) from upstream's prebuilt release, as published
to npm (`opencode-<platform>`, the package `npm i -g opencode-ai` and
opencode.ai/install use). Nothing is compiled. This is OpenCode 1, the stable
line; OpenCode 2 is still in beta.

`libexec/opencode` is upstream's single Bun-compiled binary. On macOS it is
untouched (`dontFixup`); on Linux it needs only glibc, so its interpreter is
pointed at Nix's loader (stripping is off, since that would cut off the program
Bun appends). `bin/opencode` is a wrapper that keeps it on Nix:

- `OPENCODE_DISABLE_AUTOUPDATE=1`: no check for, or notice of, newer releases.
- `opencode upgrade` is refused: it would install a second copy into
  `~/.opencode/bin`. Update the flake input instead.
- ripgrep from Nix is appended to `PATH`, so OpenCode doesn't download its own
  into `~/.cache/opencode/bin`.

Shell completions for bash and zsh come from `opencode completion`. Config,
logins and sessions stay in `~/.config/opencode` and `~/.local/share/opencode`;
plugins and language servers OpenCode fetches at runtime go to
`~/.cache/opencode`, as upstream does.

Systems: `aarch64-darwin`, `x86_64-linux`, `aarch64-linux`. The x86_64 binary
needs AVX2 (upstream's `-baseline` build is for older CPUs).

## Updates

`update.sh` follows npm's `latest` tag of `opencode-ai` and pins each platform
package by the integrity hash the registry publishes, so nothing is downloaded.
