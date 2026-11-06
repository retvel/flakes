# bend

[Bend](https://bend-lang.com) 2 from upstream's prebuilt release, the archive
`bend-lang.com/install.sh` installs. Nothing is compiled.

`libexec/bend` holds what the installer puts in `~/.bend`: `bin/bend` (one
Bun-compiled binary), `bend2/` (Base, the effects, the BendTT kernel source)
and `guide/`. On macOS the binary is untouched (`dontFixup`); on Linux it needs
only glibc, so its interpreter is pointed at Nix's loader (stripping is off,
since that would cut off the program Bun appends).

`bend file.bend` runs a file straight away: it checks it, and for a `main`
that returns `IO` builds it with clang and runs it. `bend file.bend -o file`
keeps the native binary. Packages from the hub, logins and the update check's
state stay in `~/.bend`, as upstream does.

## Off by default

- **Update check:** once a day `bend` asks bend-lang.com for the latest
  version (sending its version, OS and CPU type). The wrapper sets upstream's
  `BEND_NO_TELEMETRY=1` when it is unset; set `BEND_NO_TELEMETRY=` (empty) to
  turn the check back on.
- **`bend update`** is refused: it would install a second copy into `~/.bend`.
  Update the flake input instead.

## Compiler

Building needs clang 14 or newer (19 or newer for GPU calls, `!`). On Linux the
wrapper appends Nix's clang to `PATH`, so a `clang` or `$CC` of your own still
comes first. An older `clang` earlier on `PATH` hides Nix's: set `$CC` to a
newer one, or take the old one off `PATH`. On
macOS bend uses Apple's clang, from `xcode-select --install`.

Not provided:

- CUDA, which bend looks for under `$CUDA_HOME`, `$CUDA_PATH`,
  `/usr/local/cuda` or `/opt/cuda`. Without it, `!` calls run on the CPU.
- On Linux, the X11 and ALSA libraries that programs with a `Window` or `Audio`
  link against. Build those in a shell that has them (`libX11`, `alsa-lib`).
- Lean, which `--verdict` needs to build the BendTT kernel.

Systems: `aarch64-darwin`, `x86_64-linux`, `aarch64-linux`.

## Updates

`update.sh` reads the version and each archive's sha256 from
`bend-lang.com/install.sh` and checks every download against them, and
against GitHub's digest. On a bump, recheck in the binary's `cli_update`,
`check` and `cc_find` that `BEND_NO_TELEMETRY`, the `update` command and the
clang lookup still behave as described here.
