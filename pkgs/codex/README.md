# codex

[OpenAI Codex CLI](https://github.com/openai/codex) from upstream's prebuilt
release, as published to npm (`@openai/codex@<version>-<platform>`, the
package `npm install -g @openai/codex` pulls in). Nothing is compiled, unlike
nixpkgs' and [llm-agents.nix](https://github.com/numtide/llm-agents.nix)'
`codex`, which build it (and V8) from source.

The platform package already holds upstream's whole layout, kept as is in
`libexec/codex`: `bin/codex`, `bin/codex-code-mode-host`, `codex-path/rg`,
`codex-resources/` (bubblewrap on Linux, the voice runtime) and
`codex-package.json`. `bin/codex` is a wrapper that execs it there, since
Codex looks for those files next to its real path. Shell completions for bash, fish and zsh are
generated from the binary.

- macOS: upstream's signed binaries, untouched (`dontFixup`).
- Linux: the binaries are static (musl), except the voice host and its bundled
  GStreamer, which need only glibc: its interpreter is pointed at Nix's
  loader, and its libraries come from its own `$ORIGIN/../lib`.

Systems: `aarch64-darwin`, `x86_64-linux`, `aarch64-linux`.

## Updates

`update.sh` follows npm's `latest` tag and pins each platform package by the
integrity hash the registry publishes, so nothing is downloaded.

Codex doesn't update itself here (no `CODEX_MANAGED_BY_*` package manager is
set), and the wrapper passes `-c check_for_update_on_startup=false`, so it
doesn't look for or announce newer releases either: updates come through this
flake. The flag wins over `~/.codex/config.toml`; run
`libexec/codex/bin/codex` to get the check back.

`codex app-server daemon` would copy the running package into
`$CODEX_HOME/packages/app-server-daemon/releases` and keep that copy updated
from upstream, unless `current` there already names a package (llm-agents.nix
patches the source instead). So the wrapper points
`$CODEX_HOME/packages/app-server-daemon/current` at this package's
`libexec/codex`, replacing a link to an older one: the daemon then runs from
the store, and its updater stays off, since it only follows a release under
`releases/`. A real directory there is left alone.

Everything else in `~/.codex` (config, login, sessions) is yours; the store
holds only the program.
