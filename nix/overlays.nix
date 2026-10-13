# nix/overlays.nix — Expose fixed hermes-agent overlay for external flakes
{ inputs, ... }:
{
  flake.overlays.default = final: _: {
    hermes-agent = final.callPackage ./hermes-agent-fix.nix {
      upstreamPkg = inputs.hermes-agent.packages.${final.stdenv.hostPlatform.system}.default;
      sourcePath = inputs.hermes-agent.outPath;
    };
  };
}
