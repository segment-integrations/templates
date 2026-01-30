{
  description = "Android SDK tools for Devbox (plugin local flake)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      versionData = builtins.fromJSON (builtins.readFile ./android.json);
      defaultsData = if builtins.hasAttr "defaults" versionData then versionData.defaults else versionData;
      getVar =
        name:
        if builtins.hasAttr name defaultsData then toString (builtins.getAttr name defaultsData)
        else builtins.throw "Missing required default in devbox.d/android/android.json: ${name}";

      unique =
        list:
        builtins.foldl' (
          acc: item: if builtins.elem item acc then acc else acc ++ [ item ]
        ) [ ] list;

      lockData =
        builtins.fromJSON (
          builtins.readFile ./devices.lock.json
        );
      deviceApis =
        if builtins.hasAttr "api_versions" lockData then lockData.api_versions else [ ];
      androidSdkConfig = {
        platformVersions = unique (map toString deviceApis);
        buildToolsVersion = getVar "ANDROID_BUILD_TOOLS_VERSION";
        cmdLineToolsVersion = getVar "ANDROID_CMDLINE_TOOLS_VERSION";
        systemImageTypes = [ (getVar "ANDROID_SYSTEM_IMAGE_TAG") ];
        ndkVersion = getVar "ANDROID_NDK_VERSION";
      };

      forAllSystems =
        f:
        builtins.listToAttrs (
          map (system: {
            name = system;
            value = f system;
          }) systems
        );
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              android_sdk.accept_license = true;
            };
          };

          abiVersions = if builtins.match "aarch64-.*" system != null then [ "arm64-v8a" ] else [ "x86_64" ];

          androidPkgs =
            config:
            pkgs.androidenv.composeAndroidPackages {
              platformVersions = config.platformVersions;
              buildToolsVersions = [ config.buildToolsVersion ];
              cmdLineToolsVersion = config.cmdLineToolsVersion;
              includeEmulator = true;
              includeSystemImages = true;
              includeNDK = config.ndkVersion != "";
              ndkVersions = if config.ndkVersion != "" then [ config.ndkVersion ] else [ ];
              abiVersions = abiVersions;
              systemImageTypes = config.systemImageTypes;
            };
        in
        {
          android-sdk = (androidPkgs androidSdkConfig).androidsdk;
          default = (androidPkgs androidSdkConfig).androidsdk;
        }
      );

      androidSdkConfig = androidSdkConfig;
    };
}
