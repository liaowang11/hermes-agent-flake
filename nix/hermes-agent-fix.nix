# Keep the upstream runtime and its locked Python dependencies together.
# The release version must reach the install stamp used by plugin requirements.
{ upstreamPkg }:
upstreamPkg.override {
  version = "0.21.7";
}
