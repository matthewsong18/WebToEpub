{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  packages = [
    pkgs.cacert
    pkgs.git
    pkgs.biome
  ];

  languages.javascript = {
    enable = true;
    lsp.enable = true;
    nodejs.enable = true;
    npm.enable = true;
  };

  languages.typescript = {
    enable = true;
  };

  devcontainer = {
    enable = true;
    settings.customization.zed.extensions = [
      "nix"
    ];
  };
}
