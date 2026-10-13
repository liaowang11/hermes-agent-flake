# Keep locked dependencies and the matching source metadata together.
{
  lib,
  makeWrapper,
  runCommand,
  symlinkJoin,
  upstreamPkg,
  sourcePath,
}:
let
  runtimeSource = runCommand "hermes-runtime-source" { } ''
    cp -r ${sourcePath} "$out"
    chmod -R u+w "$out"
    substituteInPlace "$out/pm/workspace.py" \
      --replace-fail '    for entry in source.iterdir():' \
        $'    def copy_writable(source_file, target_file):\n        result = shutil.copy2(source_file, target_file)\n        Path(target_file).chmod(Path(target_file).stat().st_mode | 0o600)\n        return result\n\n    for entry in source.iterdir():' \
      --replace-fail 'shutil.copy2(entry, target)' 'copy_writable(entry, target)' \
      --replace-fail 'shutil.copytree(entry, target, ignore=ignore)' \
        $'shutil.copytree(entry, target, ignore=ignore, copy_function=copy_writable)\n            for directory, _, _ in os.walk(target):\n                Path(directory).chmod(Path(directory).stat().st_mode | 0o700)'
  '';
  versionedPackage = upstreamPkg.override {
    # Plugin requirements read this release base from the managed install stamp.
    version = "0.21.7";
  };
in
symlinkJoin {
  name = versionedPackage.name;
  paths = [ versionedPackage ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    rm "$out/bin/hermes"
    makeWrapper ${versionedPackage}/bin/hermes "$out/bin/hermes" \
      --prefix PYTHONPATH : ${lib.escapeShellArg (toString runtimeSource)}
  '';
  # PM needs pyproject.toml and uv.lock beside its code. Prepend the exact
  # source tree; appending it loses to the venv's installed package path.
  passthru = versionedPackage.passthru // {
    inherit runtimeSource;
  };
  meta = versionedPackage.meta;
}
