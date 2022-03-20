{
  description = "Cicero actions driving plutus-certification";

  inputs.cicero.url = "github:input-output-hk/cicero";

  outputs = { self, nixpkgs, cicero }: let
    inherit (cicero.lib) std;
    inherit (std) data-merge;
    lib = nixpkgs.lib;
  in {
    ciceroActions = cicero.lib.callActionsWithExtraArgs rec {
      inherit std lib;
      actionLib = import (cicero + "/action-lib.nix") { inherit std lib; };
      getDataFile = fn: ./data + "/${fn}";
      nixpkgsFlake = "github:NixOS/nixpkgs/${nixpkgs.rev}"; # TODO Get the full URL from Nix somehow
    } ./actions;
  };
}
