{
  description = "Cicero actions driving plutus-certification";

  inputs.cicero.url = "github:shlevy/cicero/cicero-api-url";

  outputs = { self, nixpkgs, cicero }: let
    inherit (cicero.lib) std;
    inherit (std) data-merge;
    lib = nixpkgs.lib;
  in {
    ciceroActions = cicero.lib.callActionsWithExtraArgs rec {
      inherit std lib;
      getDataFile = fn: ./data + "/${fn}";
      nixpkgsFlake = "github:NixOS/nixpkgs/${nixpkgs.rev}"; # TODO Get the full URL from Nix somehow
    } ./actions;
  };
}
