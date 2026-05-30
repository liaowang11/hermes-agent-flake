# nix/hermes-agent-fix.nix — Overridable fixed hermes-agent derivation
#
# callPackage auto-wires upstreamPkg and sourcePath. Use via overlay or:
#   pkgs.callPackage ./hermes-agent-fix.nix { 
#     upstreamPkg = inputs.hermes-agent.packages.x86_64-linux.default;
#     sourcePath = inputs.hermes-agent.outPath;
#   }
{
  lib,
  stdenv,
  makeWrapper,
  python3,
  python3Packages,
  fetchurl,
  upstreamPkg,
  sourcePath,
}:
let
  hermesDashboardAuth = stdenv.mkDerivation {
    name = "hermes-dashboard-auth-package";
    dontUnpack = true;
    buildInputs = [ upstreamPkg ];

    postPatch = ''
      hermes_python=$(sed -n "s|^export HERMES_PYTHON='\\(.*\\)'$|\\1|p" ${upstreamPkg}/bin/hermes)
    '';

    installPhase = ''
      hermes_python=$(sed -n "s|^export HERMES_PYTHON='\\(.*\\)'$|\\1|p" ${upstreamPkg}/bin/hermes)
      hermes_site_packages=$(find "$(dirname "$(dirname "$hermes_python")")/lib" -maxdepth 2 -type d -name site-packages | head -n1)

      test -n "$hermes_python"
      test -n "$hermes_site_packages"

      mkdir -p "$out/${python3.sitePackages}"
      cp -rL --no-preserve=mode,ownership "$hermes_site_packages/hermes_cli" "$out/${python3.sitePackages}/"
      cp -r ${sourcePath}/hermes_cli/dashboard_auth "$out/${python3.sitePackages}/hermes_cli/"
    '';
  };

  hermesLarkOapi = python3Packages.buildPythonPackage rec {
    pname = "lark-oapi";
    version = "1.5.3";
    format = "wheel";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/bf/ff/2ece5d735ebfa2af600a53176f2636ae47af2bf934e08effab64f0d1e047/lark_oapi-1.5.3-py3-none-any.whl";
      hash = "sha256-/aazK7ONIba9qulJecYAuUx8Uh6YWtreY6VOSz4gzDY=";
    };
    propagatedBuildInputs = with python3Packages; [
      httpx
      pycryptodome
      requests
      requests-toolbelt
      websockets
    ];
    doCheck = false;
  };

  hermesSupplementalPythonPath = builtins.concatStringsSep ":" [
    "${hermesDashboardAuth}/${python3.sitePackages}"
    (python3Packages.makePythonPath [
      hermesLarkOapi
      python3Packages.python-telegram-bot
      python3Packages.qrcode
    ])
  ];
in
stdenv.mkDerivation {
  name = "${upstreamPkg.name}-fixed";
  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ upstreamPkg ];

  installPhase = ''
    mkdir -p "$out/bin"
    makeWrapper ${upstreamPkg}/bin/hermes "$out/bin/hermes" \
      --prefix PYTHONPATH : ${lib.escapeShellArg hermesSupplementalPythonPath}
  '';

  meta = upstreamPkg.meta or { };
}
