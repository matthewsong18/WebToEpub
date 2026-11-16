{
  description = "Build and lint the WebToEpub browser extension";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { nixpkgs, ... }: {
    packages.x86_64-linux.default =
      let
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        fs = pkgs.lib.fileset;
      in
      pkgs.buildNpmPackage {
        pname = "webtoepub";
        version = (builtins.fromJSON (builtins.readFile ./plugin/manifest.json)).version;
        nodejs = pkgs.nodejs_24;

        src = fs.toSource {
          root = ./.;
          fileset = fs.unions [ ./package.json ./package-lock.json ./plugin ./eslint ];
        };
        npmDepsHash = "sha256-owDxI0hzXIerKtddj+CSzkjONie3/VIel6ZxSeQrerU=";
        npmRebuildFlags = [ "--ignore-scripts" ];

        buildPhase = ''
          runHook preBuild
          npm run postinstall
          npm run lint
          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          install -Dm644 -t "$out" "eslint/WebToEpub$version.zip" "eslint/WebToEpub$version.xpi"
          runHook postInstall
        '';
      };
  };
}
