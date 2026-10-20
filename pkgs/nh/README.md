# NH

Packages the official NH release binaries, pinned by version and SHA-256 hash.
No Rust compilation is performed. Supported systems: `aarch64-darwin`,
`aarch64-linux`, and `x86_64-linux`.

```nix
inputs.retvel.url = "github:retvel/flakes";
environment.systemPackages = [ inputs.retvel.packages.${system}.nh ];
```

The overlay also provides `pkgs.retvel.nh`.

The wrapper adds `nix-output-monitor` to PATH, matching the nixpkgs NH wrapper.
Nix and platform tools such as `darwin-rebuild` must be available in the caller's
PATH. Linux binaries use autoPatchelfHook for their Nix loader and runtime
libraries; the macOS binary is preserved. Upstream binary releases do not include
manpages or shell completion files.

`update.sh` refreshes all platform hashes from the latest upstream release.
