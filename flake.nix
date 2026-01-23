{
  description = "Segment shared mobile flake (Android/iOS tooling + SDKs)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f:
        builtins.listToAttrs (map (system: {
          name = system;
          value = f system;
        }) systems);
    in {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; config = { allowUnfree = true; android_sdk.accept_license = true; }; };
        in {
          android-tooling = pkgs.stdenv.mkDerivation {
            pname = "android-tooling";
            version = "1.0.0";
            src = ./.;
            installPhase = ''
              mkdir -p $out/libexec/android-tooling $out/bin
              install -m 0755 scripts/android.sh $out/libexec/android-tooling/android.sh
              cat > $out/bin/android-tooling <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$#" -eq 1 && "$1" == "--path" ]]; then
  exec printf "%s\n" "$out/libexec/android-tooling/android.sh"
fi
exec "$out/libexec/android-tooling/android.sh" "$@"
SH
              chmod +x $out/bin/android-tooling
            '';
          };

          ios-tooling = pkgs.stdenv.mkDerivation {
            pname = "ios-tooling";
            version = "1.0.0";
            src = ./.;
            installPhase = ''
              mkdir -p $out/libexec/ios-tooling $out/bin
              install -m 0755 scripts/ios.sh $out/libexec/ios-tooling/ios.sh
              cat > $out/bin/ios-tooling <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$#" -eq 1 && "$1" == "--path" ]]; then
  exec printf "%s\n" "$out/libexec/ios-tooling/ios.sh"
fi
exec "$out/libexec/ios-tooling/ios.sh" "$@"
SH
              chmod +x $out/bin/ios-tooling
            '';
          };
        });

    };
}
