# AGENTS.md

**Never build Hermes agents on the current machine (this macOS workstation).**
Builds target the `asus-pn50` machine. Use evaluation-only checks locally; see
"Do not build locally" below.

## What this repo is

A thin Nix flake wrapping the upstream `NousResearch/hermes-agent` package. The
upstream package builds but the `hermes` CLI is missing runtime pieces; this
flake re-wraps it to supply them. See `README.md` for the user-facing story.

## Do not build locally

Never build Hermes Agent packages on this workstation (macOS/arm64). Builds
target the `asus-pn50` machine (x86_64-linux) and CI. Verify changes locally
with **evaluation only**:

```sh
# all systems evaluate
nix flake show

# specific x86_64-linux derivations resolve
for a in default full messaging tui web; do
  nix eval --raw .#packages.x86_64-linux.$a.drvPath
done
```

Real build verification happens in CI (`.github/workflows/build.yml`, also
manually dispatchable: `gh workflow run Build --ref main`). Note: push- and
schedule-triggered workflows have been observed silently not firing; if a run
doesn't appear after a push, dispatch manually and check the run list.

## Layout

| Path | Purpose |
| --- | --- |
| `flake.nix` | Inputs: nixpkgs (nixos-unstable), flake-parts, hermes-agent (tracks upstream `main`). |
| `nix/packages.nix` | Builds the `default` wrapped package and re-exposes upstream variants (`full`, `messaging`, `tui`, `web`) plus checks. |
| `nix/overlays.nix` | Exposes `overlays.default` (`pkgs.hermes-agent` = fixed derivation). |
| `nix/hermes-agent-fix.nix` | Overridable `callPackage` derivation holding the actual fix; keeps it duplicable from other flakes. |

`hermes-agent-fix.nix` owns the release-base version override used by both
packages and overlay. Keep that version aligned with the newest release tag
that is an ancestor of the pinned source: plugin minimum-version checks read
it from the install stamp. Upstream now owns runtime resources and locked Python
dependencies. Supplemental `PYTHONPATH` copies previously shadowed the Feishu
SDK and mixed interpreter versions; keep the runtime dependency graph together.
Run `checks.x86_64-linux.runtime-compatibility` on asus-pn50 after changes.

## Updating inputs

Manual bumps follow the convention in `git log`:

```sh
nix flake update          # updates nixpkgs, flake-parts, hermes-agent together
# verify evaluation (see above), then:
git commit -m "chore: update Hermes Agent to vX.Y.Z"
```

- Upstream releases are tagged `vX.Y.Z` (older ones also carry date tags like
  `v2026.9.24`);
  find the latest with `git ls-remote --tags https://github.com/NousResearch/hermes-agent`.
  The lock tracks `main`, which sits slightly ahead of the newest release tag —
  name the commit after the newest tag, not the locked rev.
- CI does the same weekly (Friday) and commits as "Update flake inputs".
- Upstream's Nix version defaults to `0.0.0`; this flake supplies the release
  base version so plugin version requirements work in managed installs.
- Prefer `gh api repos/NousResearch/hermes-agent/contents/...` over
  `raw.githubusercontent.com` when inspecting upstream files — the raw host
  rate-limits quickly.

## Conventions

- Commit messages: `chore: update Hermes Agent to vX.Y.Z` for manual hermes
  bumps; `fix:`/`ci:` prefixes for other work. CI auto-commits use
  "Update flake inputs". No co-author/agent trailers.
- Commits go straight to `main` (matching CI and history).
- CI pushes to the `iosevka-wliao` Cachix cache.
