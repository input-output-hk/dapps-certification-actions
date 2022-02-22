{ name, std, lib, getDataFile, nixpkgsFlake, ... }@args:
{
  inputs = {
    repo-ref = ''
      "${name}": ref: string // Flake reference in URL format
    '';
  };

  outputs = { ... }: {
    failure.${name}.failure = true;
  };

  job = { repo-ref }: std.chain args [
    (std.escapeNames [ ] [ ])

    std.singleTask

    {
      config.packages = std.data-merge.append [
        "${nixpkgsFlake}#gnutar"
        "${nixpkgsFlake}#gzip"
        "${nixpkgsFlake}#bash"
      ];
    }

    std.postFact

    std.nix.install

    (std.script "bash" ''
      set -eEuo pipefail

      nix flake metadata --no-update-lock-file --json ${lib.escapeShellArg repo-ref.value.${name}.ref} > metadata.json
      metadataNix="$(nix eval --impure --expr '(builtins.fromJSON (builtins.readFile ./metadata.json)).locked')"

      mkdir flake
      cat > flake/flake.nix <<EOF
      {
        inputs = {
          repo = $metadataNix;
          plutus-apps.url = "github:Quviq/plutus-apps/PR-certification-framework";
        };

        outputs = args: import ./outputs.nix args;
      }
      EOF
      echo ${lib.escapeShellArg (builtins.readFile (getDataFile "outputs.nix"))} > flake/outputs.nix
      echo ${lib.escapeShellArg (builtins.readFile (getDataFile "Certify.hs"))} > flake/Certify.hs

      tar czf /local/cicero/post-fact/success/artifact flake
      echo ${lib.escapeShellArg (builtins.toJSON {
        ${name}.success = true;
      })} > /local/cicero/post-fact/success/fact
    '')
  ];
}
