# Use upstream runtime resources and dependency locks without PYTHONPATH overrides.
{ lib, ... }:
{
  perSystem =
    { pkgs, inputs', ... }:
    let
      hermesPackage = pkgs.callPackage ./hermes-agent-fix.nix {
        upstreamPkg = inputs'.hermes-agent.packages.default;
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
          ${hermesPackage.hermesVenv}/bin/python3 - <<'PY'
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
