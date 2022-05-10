{ plutus-apps, repo, ... }: let
  origProject = repo.iog.dapp;

  inherit (origProject) pkgs;

  modifiedCabalProject = pkgs.runCommand "cabal.project" {} ''
    mkdir -p $out
    echo ${pkgs.lib.escapeShellArg origProject.args.cabalProject} | sed 's|^  *plutus-contract-certification$||g' > $out/cabal.project
  '';

  project = origProject.appendModule ({ lib, ... }: {
    cabalProject = lib.mkForce (builtins.readFile "${modifiedCabalProject}/cabal.project");
    cabalProjectLocal = lib.mkForce (origProject.args.cabalProjectLocal + ''
      source-repository-package
        type: git
        location: https://github.com/input-output-hk/plutus-apps
        tag: ${plutus-apps.rev}
        --sha256: ${import (pkgs.stdenv.mkDerivation {
          name = "plutus-apps-sha.nix";
          exportReferencesGraph.plutus-apps = plutus-apps;
          __structuredAttrs = true;
          PATH = pkgs.lib.makeBinPath [ pkgs.coreutils pkgs.jq ];
          builder = builtins.toFile "builder" ''
            . .attrs.sh
            jq '."plutus-apps"[0].narHash' < .attrs.json > "$(jq -r .outputs.out < .attrs.json)"
          '';
        })}
        subdir:
          plutus-contract-certification
      '');
    materialized = lib.mkForce null;
  });

  ghc = project.ghcWithPackages (p: [ p.plutus-contract-certification p.certification ]);
in {
  defaultPackage.x86_64-linux = pkgs.runCommand "certify" {} ''
    mkdir -p $out/bin
    ${ghc}/bin/ghc ${./Certify.hs} -o $out/bin/certify -L${pkgs.numactl}/lib
  '';
}
