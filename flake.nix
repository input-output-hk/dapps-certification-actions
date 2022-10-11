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
      nixpkgsFlake = "github:NixOS/nixpkgs/${nixpkgs.rev}"; # TODO Get the full URL from Nix somehow
      helperFlakeInput = exe: "github:input-output-hk/dapps-certification#dapps-certification-helpers:exe:${exe}";
    } ./actions;
  };
}
