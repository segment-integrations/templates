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

      devicesDir = ./devices;
      evaluateDevices =
        if builtins.hasAttr "EVALUATE_DEVICES" defaultsData then defaultsData.EVALUATE_DEVICES else [ ];
      deviceFiles =
        let
          entries = builtins.readDir devicesDir;
          names = builtins.attrNames entries;
          allFiles = builtins.filter (name: builtins.match ".*\\.json" name != null) names;
          normalize = name: builtins.replaceStrings [ ".json" ] [ "" ] name;
          matches =
            selection: file:
            let
              data = builtins.fromJSON (builtins.readFile (devicesDir + "/${file}"));
              deviceName = if builtins.hasAttr "name" data then toString data.name else "";
            in
            normalize file == selection || deviceName == selection;
          resolveSelection =
            selection:
            let
              filtered = builtins.filter (matches selection) allFiles;
            in
            if filtered == [ ] then builtins.throw "EVALUATE_DEVICES '${selection}' not found in devbox.d/android/devices."
            else filtered;
          selectedFiles = builtins.concatLists (map resolveSelection evaluateDevices);
        in
        if evaluateDevices == [ ] then allFiles else unique selectedFiles;
      deviceApis =
        let
          apiFromFile =
            name:
            let
              data = builtins.fromJSON (builtins.readFile (devicesDir + "/${name}"));
            in
            if builtins.hasAttr "api" data then toString data.api else null;
        in
        builtins.filter (api: api != null) (map apiFromFile deviceFiles);
      androidSdkConfig = {
        platformVersions = unique deviceApis;
        buildToolsVersion = getVar "ANDROID_BUILD_TOOLS_VERSION";
        cmdLineToolsVersion = getVar "ANDROID_CMDLINE_TOOLS_VERSION";
        systemImageTypes = [ (getVar "ANDROID_SYSTEM_IMAGE_TAG") ];
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
              includeNDK = false;
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
