# hermes-agent-flake

A Nix flake that supplies release identity for the upstream
[`NousResearch/hermes-agent`](https://github.com/NousResearch/hermes-agent) package.

## What it fixes

The upstream Nix derivation defaults to version `0.0.0`. This flake overrides it
with the source's release base version, currently `0.21.7`, so the runtime install
stamp allows plugins with minimum Hermes version requirements. Update this base
version when advancing the source past a newer release; retain the upstream
revision and Nix-managed update mechanism.

The upstream full package now supplies dashboard authentication, locale resources,
and locked messaging dependencies, including Feishu SDK 1.6.8. Earlier versions
of this flake copied Python packages and added supplemental dependencies to
`PYTHONPATH`. Those overrides are removed: they shadowed the correct SDK and mixed
Python 3.13 dependencies into the Python 3.14 runtime.

The `runtime-compatibility` check constructs a Feishu WebSocket client with the
channel user-agent tag and checks the installed CLI's release version.

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
