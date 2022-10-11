{ name, std, lib, helperFlakeInput, nixpkgsFlake, ... }@args:
{
  inputs = {
    repo-ref = ''
      "${name}": ref: string // Flake reference in URL format
    '';
  };

  output = { ... }: {
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
        (helperFlakeInput "generate-flake")
      ];

      config.console = "pipe";
    }

    std.postFact

    std.nix.install

    (std.script "bash" ''
      set -eEuo pipefail

      generate-flake ${lib.escapeShellArg repo-ref.value.${name}.ref} flake

      tar czf /local/cicero/post-fact/success/artifact flake
      echo ${lib.escapeShellArg (builtins.toJSON {
        ${name}.success = true;
      })} > /local/cicero/post-fact/success/fact
    '')
  ];
}
