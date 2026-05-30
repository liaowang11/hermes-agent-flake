{
  description = "Fixed Nix flake for Hermes Agent — wraps upstream with dashboard_auth, lark-oapi, python-telegram-bot, and qrcode";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    hermes-agent.url = "github:NousResearch/hermes-agent";
  };

  outputs =
    inputs @ { flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      imports = [ ./nix/packages.nix ./nix/overlays.nix ];
    };
}
