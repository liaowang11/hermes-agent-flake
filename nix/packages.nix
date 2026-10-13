# Use upstream locked dependencies with matching source metadata for plugin PM.
{ inputs, lib, ... }:
{
  perSystem =
    { pkgs, inputs', ... }:
    let
      hermesPackage = pkgs.callPackage ./hermes-agent-fix.nix {
        upstreamPkg = inputs'.hermes-agent.packages.default;
        sourcePath = inputs.hermes-agent.outPath;
      };
    in
    {
      packages =
        builtins.removeAttrs inputs'.hermes-agent.packages [ "sandbox" ]
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          inherit (inputs'.hermes-agent.packages) sandbox;
        }
        // {
          default = hermesPackage;
          full = hermesPackage;
        };

      checks = {
        inherit (inputs'.hermes-agent.checks) cross-eval;
        runtime-compatibility = pkgs.runCommand "hermes-runtime-compatibility" { } ''
          export HOME="$TMPDIR/home"
          mkdir -p "$HOME"
          PYTHONPATH=${hermesPackage.runtimeSource} ${hermesPackage.hermesVenv}/bin/python3 - <<'PY'
          import tempfile
          from pathlib import Path
          from pm.paths import repo_root
          from pm.workspace import _generate_pyproject
          with tempfile.TemporaryDirectory() as temporary:
              workspace = Path(temporary) / "workspace"
              _generate_pyproject([], workspace, source=repo_root())
              with (workspace / "pyproject.toml").open("a") as output:
                  output.write("\n# plugin transaction\n")
              with (workspace / "pm" / "transaction-smoke").open("w") as output:
                  output.write("writable snapshot")
              assert (workspace / "pm" / "transaction-smoke").read_text() == "writable snapshot"
              assert not (repo_root() / "pyproject.toml").stat().st_mode & 0o200
              assert (workspace / "pyproject.toml").stat().st_mode & 0o200
          from lark_oapi.ws import Client
          client = Client("test-app", "test-secret", extra_ua_tags=["channel"])
          assert "channel" in client._user_agent, client._user_agent
          PY
          ${hermesPackage}/bin/hermes --version > version.txt
          grep -F '0.21.7' version.txt
          touch "$out"
        '';
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        inherit (inputs'.hermes-agent.checks)
          package-contents
          entry-points-sync
          cli-commands
          bundled-skills
          bundled-plugins
          bundled-tui
          hermes-node
          managed-guard
          extra-python-packages
          extra-dependency-groups
          messaging-variant
          config-roundtrip
          ;
      };
    };
}
