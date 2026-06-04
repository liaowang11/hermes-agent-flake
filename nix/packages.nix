# nix/packages.nix — Wraps upstream hermes-agent package with supplemental Python deps
# and re-exposes upstream variant packages for CI builds.
{
  inputs,
  lib,
  ...
}:
{
  perSystem =
    {
      pkgs,
      inputs',
      ...
    }:
    let
      directHermesPackage = inputs'.hermes-agent.packages.default;

      hermesSource = inputs.hermes-agent.outPath;

      hermesDashboardAuth = pkgs.runCommand "hermes-dashboard-auth-package" { } ''
        hermes_python=$(sed -n "s|^export HERMES_PYTHON='\\(.*\\)'\$|\\1|p" ${directHermesPackage}/bin/hermes)
        hermes_site_packages=$(find "$(dirname "$(dirname "$hermes_python")")/lib" -maxdepth 2 -type d -name site-packages | head -n1)

        test -n "$hermes_python"
        test -n "$hermes_site_packages"

        mkdir -p "$out/${pkgs.python3.sitePackages}"
        cp -rL --no-preserve=mode,ownership "$hermes_site_packages/hermes_cli" "$out/${pkgs.python3.sitePackages}/"
        cp -r ${hermesSource}/hermes_cli/dashboard_auth "$out/${pkgs.python3.sitePackages}/hermes_cli/"
      '';

      hermesLarkOapi = pkgs.python3Packages.buildPythonPackage rec {
        pname = "lark-oapi";
        version = "1.5.3";
        format = "wheel";
        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/bf/ff/2ece5d735ebfa2af600a53176f2636ae47af2bf934e08effab64f0d1e047/lark_oapi-1.5.3-py3-none-any.whl";
          hash = "sha256-/aazK7ONIba9qulJecYAuUx8Uh6YWtreY6VOSz4gzDY=";
        };
        propagatedBuildInputs = with pkgs.python3Packages; [
          httpx
          pycryptodome
          requests
          requests-toolbelt
          websockets
        ];
        doCheck = false;
      };

      # Shim that monkey-patches agent.i18n._locales_dir to check the
      # HERMES_LOCALES_DIR env var, so the nix store package can find locale
      # YAML files bundled at a known store path.
      #
      # Delivered as sitecustomize.py rather than a .pth import line: the shim
      # is added via PYTHONPATH, and .pth files are only executed for genuine
      # site directories, not arbitrary PYTHONPATH entries.  sitecustomize is
      # imported by name from sys.path, so it runs at interpreter startup
      # either way.
      hermesLocalesShim = pkgs.stdenv.mkDerivation {
        name = "hermes-locales-shim";
        dontUnpack = true;
        installPhase = ''
                    mkdir -p $out/${pkgs.python3.sitePackages}
                    cat > $out/${pkgs.python3.sitePackages}/sitecustomize.py << 'PY'
          """Monkey-patch agent.i18n._locales_dir to honor HERMES_LOCALES_DIR."""
          import os
          from pathlib import Path

          try:
              import agent.i18n as _mod
              _orig = _mod._locales_dir

              def _patched_locales_dir():
                  env = os.environ.get("HERMES_LOCALES_DIR")
                  if env:
                      p = Path(env)
                      if p.is_dir():
                          return p
                  return _orig()

              _mod._locales_dir = _patched_locales_dir
          except ImportError:
              pass
          PY
        '';
      };

      hermesLocalesDir = "${hermesSource}/locales";

      hermesSupplementalPythonPath = builtins.concatStringsSep ":" [
        "${hermesDashboardAuth}/${pkgs.python3.sitePackages}"
        "${hermesLocalesShim}/${pkgs.python3.sitePackages}"
        (pkgs.python3Packages.makePythonPath [
          hermesLarkOapi
          pkgs.python3Packages.python-telegram-bot
          pkgs.python3Packages.qrcode
        ])
      ];
    in
    {
      packages = {
        default = pkgs.symlinkJoin {
          name = directHermesPackage.name;
          paths = [ directHermesPackage ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            rm "$out/bin/hermes"
            makeWrapper ${directHermesPackage}/bin/hermes "$out/bin/hermes" \
              --prefix PYTHONPATH : ${lib.escapeShellArg hermesSupplementalPythonPath} \
              --set HERMES_LOCALES_DIR ${hermesLocalesDir}
          '';
          meta = directHermesPackage.meta or { };
        };

        inherit (inputs'.hermes-agent.packages)
          messaging
          full
          tui
          web
          fix-lockfiles
          ;
      };

      checks = {
        inherit (inputs'.hermes-agent.checks)
          cross-eval
          ;
      }
      // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
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
