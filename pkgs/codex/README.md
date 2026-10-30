# codex

[OpenAI Codex CLI](https://github.com/openai/codex) from upstream's prebuilt
release, as published to npm (`@openai/codex@<version>-<platform>`, the
package `npm install -g @openai/codex` pulls in). Nothing is compiled, unlike
nixpkgs' and [llm-agents.nix](https://github.com/numtide/llm-agents.nix)'
`codex`, which build it (and V8) from source.

The platform package already holds upstream's whole layout, kept as is in
`libexec/codex`: `bin/codex`, `bin/codex-code-mode-host`, `codex-path/rg`,
`codex-resources/` (bubblewrap on Linux, the voice runtime) and
`codex-package.json`. `bin/codex` links to it, since Codex looks for those
files next to its real path. Shell completions for bash, fish and zsh are
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
set); at most it shows an "Update available" notice. Turn that off with
`check_for_update_on_startup = false` in `~/.codex/config.toml`; updates come
through this flake.

`codex app-server` daemon mode copies the running package into
`~/.codex/packages/standalone` and updates that copy itself, as for any npm
install; llm-agents.nix patches that out, which a prebuilt binary can't.
The CLI itself runs from the store.
