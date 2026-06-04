# hermes-agent-flake

A Nix flake that wraps the upstream [`NousResearch/hermes-agent`](https://github.com/NousResearch/hermes-agent)
package and fixes a handful of runtime gaps so the CLI works out of the box from
the Nix store.

## What it fixes

The upstream package builds, but the `hermes` CLI is missing pieces it needs at
runtime. This flake re-wraps the upstream binary to supply them:

- **`dashboard_auth`** — the upstream `hermes_cli.dashboard_auth` subpackage is
  copied in from source alongside the installed `hermes_cli`.
- **Extra Python dependencies** — `lark-oapi` (built from the published wheel),
  `python-telegram-bot`, and `qrcode` are added to `PYTHONPATH`.
- **Locale discovery** — a `sitecustomize.py` shim monkey-patches
  `agent.i18n._locales_dir` to honor a `HERMES_LOCALES_DIR` environment variable,
  which the wrapper points at the locale YAML files bundled at a known store path.

The wrapper sets `PYTHONPATH` and `HERMES_LOCALES_DIR` via `makeWrapper`, leaving
the upstream entry point otherwise untouched.

## Usage

### Run directly

```sh
nix run github:wliao/hermes-agent-flake
```

### Build a package

```sh
nix build .#default      # fixed hermes CLI
nix build .#full
nix build .#messaging
nix build .#tui
nix build .#web
```

The `default` package is the fixed wrapper. `full`, `messaging`, `tui`, and `web`
are re-exposed upstream variants for CI builds.

### Use the overlay

To pull the fixed `hermes-agent` into another flake's package set:

```nix
{
  inputs.hermes-agent-flake.url = "github:wliao/hermes-agent-flake";

  # ...
  nixpkgs.overlays = [ inputs.hermes-agent-flake.overlays.default ];
  # pkgs.hermes-agent now resolves to the fixed derivation
}
```

The fix itself lives in [`nix/hermes-agent-fix.nix`](nix/hermes-agent-fix.nix) as
an overridable `callPackage` derivation, so you can also wire it up manually:

```nix
pkgs.callPackage ./nix/hermes-agent-fix.nix {
  upstreamPkg = inputs.hermes-agent.packages.x86_64-linux.default;
  sourcePath = inputs.hermes-agent.outPath;
}
```

## Layout

| Path | Purpose |
| --- | --- |
| `flake.nix` | Flake entry point; wires up `flake-parts` and the two modules below. |
| `nix/packages.nix` | Builds the `default` package and re-exposes upstream variants and checks. |
| `nix/overlays.nix` | Exposes `overlays.default` for external consumers. |
| `nix/hermes-agent-fix.nix` | The overridable fixed derivation. |

## Supported systems

`x86_64-linux`, `aarch64-linux`, and `aarch64-darwin`.

## CI

Two GitHub Actions workflows keep the flake building and seed a binary cache:

- **`build.yml`** — on pull requests, pushes to `main`, and manual dispatch,
  runs `nix flake check` and builds each package in the matrix, pushing results
  to Cachix (pushes are skipped for pull requests).
- **`update-flake-inputs.yml`** — weekly (and on demand), runs `nix flake update`,
  commits the refreshed `flake.lock`, and rebuilds to populate the cache.

Both push to the `iosevka-wliao` Cachix cache and require a `CACHIX_AUTH_TOKEN`
repository secret.
